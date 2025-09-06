// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable2Step} from "./oz/Ownable2Step.sol";
import {ReentrancyGuard} from "./oz/ReentrancyGuard.sol";
import {Pausable} from "./oz/Pausable.sol";
import {EpochLib} from "reka-common/libs/EpochLib.sol";
import {ISwapAdapter} from "reka-common/adapters/ISwapAdapter.sol";
import {IEthenaStakingAdapter} from "reka-common/adapters/IEthenaStakingAdapter.sol";
import {IStargateAdapter} from "reka-common/adapters/IStargateAdapter.sol";
import {SafeERC20Compat} from "reka-common/utils/SafeERC20Compat.sol";
import {IPriceFeed} from "reka-common/pricefeed/IPriceFeed.sol";
import {IStrategyModule} from "./modules/IStrategyModule.sol";

contract EpochEthenaStrategy is Ownable2Step, ReentrancyGuard, Pausable {
    using EpochLib for EpochLib.EpochState;
    using SafeERC20Compat for IERC20;

    IERC20 public immutable USDT;
    IERC20 public immutable USDe;
    IERC20 public immutable sUSDe;

    ISwapAdapter public swap;
    IEthenaStakingAdapter public staking;
    IStargateAdapter public bridge;

    uint16  public kaiaChainId;
    address public kaiaRecipient;

    uint256 public queuedWithdrawalUSDT;
    uint256 public slippageBps; // ≤ 100

    // ========== Idempotency ==========
    uint64 public lastProcessedEpoch; // epoch index of last successful rollover

    // ========== Throttle ==========
    uint16 public redeemThrottleBps = 3000; // max % of TVL redeemable per epoch (default 30%)

    // ========== Price feeds ==========
    IPriceFeed public pfUSDTtoUSDe;
    IPriceFeed public pfUSDetoUSDT;

    // ========== Circuit breaker ==========
    enum Health { OK, STALE, DEPEG, VOLATILE, PAUSED }
    Health public health;

    uint16 public maxDeviationBps = 1500; // 15%
    uint64 public maxAgeSecFallback = 3600; // 1h
    bool   public breakerEnabled = true;

    uint256 public lastOkUSDTtoUSDe; // USDe per USDT
    uint256 public lastOkUSDetoUSDT; // USDT per USDe

    // ========== Module Management ==========
    struct ModuleInfo {
        IStrategyModule module;
        uint16 targetBps;        // 0..10000
        bool active;
    }
    ModuleInfo[] public modules;
    uint16 public driftBps = 500; // 5% drift threshold
    uint16 public minTradeBps = 50; // 0.5% of TVL minimum move
    
    // ========== Performance Fee ==========
    address public feeRecipient;
    uint16 public performanceFeeBps; // 0..2000 (max 20%)
    uint256 public highWaterMarkUSDT;
    
    EpochLib.EpochState private _epoch;
    address public operator;

    event OperatorUpdated(address indexed op);
    event KaiaRecipientUpdated(uint16 chainId, address to);
    event AdaptersUpdated(address swap, address staking, address bridge);
    event WithdrawalQueued(uint256 amountUSDT);
    event EpochRollover(uint64 prevEpoch, uint64 newEpoch, uint256 bridgedUSDT, uint256 stakedUSDe);

    // ========== Events ==========
    event RolloverPrecheck(uint64 epoch, uint256 tvlUSDT, uint256 queuedUSDT);
    event RolloverExecuted(uint64 epoch, uint256 bridgedUSDT, uint256 stakedUSDe, uint256 redeemedUSDe, uint256 usdtOutForWithdrawals);
    event ThrottleUpdated(uint16 oldBps, uint16 newBps);
    event SlippageUpdated(uint16 oldBps, uint16 newBps);
    
    // ========== Price feed events ==========
    event PriceFeedsUpdated(address pfUSDTtoUSDe, address pfUSDetoUSDT);
    event BreakerUpdated(bool enabled, uint16 maxDeviationBps, uint64 maxAgeSecFallback);
    event HealthChanged(Health oldH, Health newH, uint256 p1, uint256 p2, uint64 ts);
    event InvestSkipped(string reason);
    
    // ========== Module events ==========
    event ModuleAdded(uint256 idx, address module, uint16 targetBps);
    event ModuleUpdated(uint256 idx, uint16 targetBps, bool active);
    event Rebalanced(uint64 epoch, uint256 tvl, int256[] deltasUSDT);
    event PerformanceFeeTaken(uint256 feeUSDT);

    modifier onlyOperator() {
        require(msg.sender == operator, "NOT_OPERATOR");
        _;
    }

    constructor(
        address usdt,
        address usde,
        address sUsde,
        address swapAdapter,
        address stakingAdapter,
        address bridgeAdapter,
        uint16  _kaiaChainId,
        address _kaiaRecipient,
        uint256 _slippageBps,
        address _owner
    ) Ownable2Step(_owner) {
        require(usdt != address(0) && usde != address(0) && sUsde != address(0), "ZERO_TOKEN");
        require(swapAdapter != address(0) && stakingAdapter != address(0) && bridgeAdapter != address(0), "ZERO_ADAPTER");
        require(_kaiaRecipient != address(0), "ZERO_RECIPIENT");
        require(_slippageBps <= 100, "SLIP_MAX_100");

        USDT = IERC20(usdt);
        USDe = IERC20(usde);
        sUSDe = IERC20(sUsde);
        swap = ISwapAdapter(swapAdapter);
        staking = IEthenaStakingAdapter(stakingAdapter);
        bridge = IStargateAdapter(bridgeAdapter);
        kaiaChainId = _kaiaChainId;
        kaiaRecipient = _kaiaRecipient;
        slippageBps = _slippageBps;

        _epoch.init();
        operator = _owner;

        USDT.safeApprove(address(swap), type(uint256).max);
        USDe.safeApprove(address(swap), type(uint256).max);
        USDe.safeApprove(address(staking), type(uint256).max);
    }

    // ---- views ----
    function epochInfo() external view returns (uint64 currentEpoch, uint64 nextRolloverAt) {
        return (_epoch.currentEpoch, _epoch.nextRolloverAt);
    }
    function canRollover() external view returns (bool) { return _epoch.canRollover(); }

    function totalUSDTEquivalent() public view returns (uint256) {
        uint256 usdtBal = USDT.balanceOf(address(this));
        uint256 sBal = staking.sUSDeBalance();
        if (sBal == 0) return usdtBal;
        uint256 usdeEst = staking.previewRedeem(sBal);
        uint256 usdtFromUsde = swap.quoteUSDetoUSDT(usdeEst);
        return usdtBal + usdtFromUsde;
    }

    // ---- admin ----
    function setOperator(address op) external onlyOwner { require(op != address(0),"ZERO"); operator = op; emit OperatorUpdated(op); }
    
    function setSlippageBps(uint16 bps) external onlyOwner {
        require(bps <= 500, "max 5%"); // sensible safety bound
        emit SlippageUpdated(uint16(slippageBps), bps);
        slippageBps = bps;
    }
    
    function setRedeemThrottleBps(uint16 bps) external onlyOwner {
        require(bps <= 10_000, "bps>100%");
        emit ThrottleUpdated(redeemThrottleBps, bps);
        redeemThrottleBps = bps;
    }
    
    function setPriceFeeds(address p1, address p2) external onlyOwner {
        pfUSDTtoUSDe = IPriceFeed(p1);
        pfUSDetoUSDT = IPriceFeed(p2);
        emit PriceFeedsUpdated(p1, p2);
    }

    function setBreakerParams(bool enabled, uint16 devBps, uint64 maxAge) external onlyOwner {
        require(devBps <= 10_000, "dev>100%");
        breakerEnabled = enabled;
        maxDeviationBps = devBps;
        maxAgeSecFallback = maxAge;
        emit BreakerUpdated(enabled, devBps, maxAge);
    }
    
    function setKaiaRecipient(uint16 chainId, address to) external onlyOwner { require(to!=address(0),"ZERO"); kaiaChainId=chainId; kaiaRecipient=to; emit KaiaRecipientUpdated(chainId,to); }
    function setAdapters(address swapAdapter, address stakingAdapter, address bridgeAdapter) external onlyOwner {
        if (swapAdapter!=address(0)) swap = ISwapAdapter(swapAdapter);
        if (stakingAdapter!=address(0)) staking = IEthenaStakingAdapter(stakingAdapter);
        if (bridgeAdapter!=address(0)) bridge = IStargateAdapter(bridgeAdapter);
        emit AdaptersUpdated(address(swap), address(staking), address(bridge));
    }
    function pause() external onlyOwner { 
        _pause(); 
    }
    
    function unpause() external onlyOwner { 
        _unpause(); 
    }
    
    // ---- module management ----
    function addModule(address m, uint16 targetBps_) external onlyOwner {
        require(targetBps_ <= 10_000, "bps");
        modules.push(ModuleInfo({
            module: IStrategyModule(m), 
            targetBps: targetBps_, 
            active: true
        }));
        emit ModuleAdded(modules.length - 1, m, targetBps_);
    }
    
    function setModule(uint256 idx, uint16 targetBps_, bool active_) external onlyOwner {
        require(idx < modules.length, "idx");
        modules[idx].targetBps = targetBps_;
        modules[idx].active = active_;
        emit ModuleUpdated(idx, targetBps_, active_);
    }
    
    function setRebalanceParams(uint16 drift, uint16 minTrade) external onlyOwner {
        require(drift <= 5000 && minTrade <= 1000, "bounds");
        driftBps = drift;
        minTradeBps = minTrade;
    }
    
    function setPerformanceFee(uint16 bps, address to) external onlyOwner {
        require(bps <= 2000, "fee too high");
        performanceFeeBps = bps;
        feeRecipient = to;
    }

    // ---- ops ----
    function scheduleWithdrawal(uint256 usdtAmount) external onlyOperator {
        require(usdtAmount > 0, "ZERO");
        queuedWithdrawalUSDT += usdtAmount;
        emit WithdrawalQueued(usdtAmount);
    }

    /// Weekly batch: redeem % from sUSDe, swap to USDT, bridge to KAIA; then invest remainder USDT
    function rolloverEpoch(bytes calldata stargateExtra) external payable onlyOperator nonReentrant whenNotPaused {
        uint64 prev = _epoch.currentEpoch;
        
        // Emit precheck event before tick
        uint256 tvl = totalUSDTEquivalent();
        emit RolloverPrecheck(prev, tvl, queuedWithdrawalUSDT);
        
        _epoch.tick();
        uint64 cur = _epoch.currentEpoch;
        
        // Idempotent rollover guard (check after tick to ensure we track new epoch)
        require(cur > lastProcessedEpoch, "AlreadyProcessed");

        uint256 bridged = _processQueuedWithdrawals(stargateExtra);
        uint256 staked  = _investRemainder();
        
        // Take performance fee if applicable
        _takePerformanceFee();

        // Update last processed epoch
        lastProcessedEpoch = cur;
        
        // Emit execution event (using 0 for redeemedUSDe since we track it differently)
        emit RolloverExecuted(cur, bridged, staked, 0, bridged);
        emit EpochRollover(prev, cur, bridged, staked);
    }

    // ---- internals ----
    function _bridgeUSDT(uint256 amount, bytes calldata extra) internal {
        bridge.bridgeUSDT{value: address(this).balance}(
            kaiaChainId,
            kaiaRecipient,
            amount,
            (amount * (10_000 - slippageBps)) / 10_000,
            extra
        );
    }
    
    function _processQueuedWithdrawals(bytes calldata extra) internal returns (uint256 bridgedUSDT) {
        uint256 queued = queuedWithdrawalUSDT;
        if (queued == 0) return 0;

        uint256 tvl = totalUSDTEquivalent();
        if (tvl == 0) { queuedWithdrawalUSDT = 0; return 0; }

        // Apply throttle: limit redemption to % of TVL
        uint256 maxRedeem = tvl * redeemThrottleBps / 10_000;
        uint256 redeemNow = queued > maxRedeem ? maxRedeem : queued;
        
        if (redeemNow == 0) {
            // Skip redemption this epoch, carry over queue
            return 0;
        }

        // Calculate proportion to redeem based on throttled amount
        uint256 propBps = redeemNow * 10_000 / tvl;
        if (propBps > 10_000) propBps = 10_000;

        uint256 sBal = staking.sUSDeBalance();
        if (sBal > 0 && propBps > 0) {
            uint256 sToRedeem = sBal * propBps / 10_000;
            if (sToRedeem > 0) {
                uint256 usdeOut = staking.unstake(sToRedeem);
                
                (bool redeemOk, uint256 pBack) = _precheckRedeem(usdeOut);
                if (redeemOk) {
                    uint256 usdtOut = _applySlippageGuardOnUSDeToUSDT(usdeOut);
                    if (usdtOut > 0) {
                        _bridgeUSDT(usdtOut, extra);
                        bridgedUSDT = usdtOut;
                        
                        // Reduce queue by amount actually processed
                        queuedWithdrawalUSDT = queuedWithdrawalUSDT > usdtOut ? (queuedWithdrawalUSDT - usdtOut) : 0;
                        _updateLastOk(0, pBack);
                    }
                }
            }
        }
    }

    function _investRemainder() internal returns (uint256 stakedUsde) {
        // If modules are configured, use rebalancing instead
        if (modules.length > 0) {
            _rebalancePortfolio();
            return 0;
        }
        
        // Legacy path: direct Ethena investment
        uint256 usdtBal = USDT.balanceOf(address(this));
        if (usdtBal == 0) return 0;
        
        (bool investOk, uint256 pFwd) = _precheckInvest(usdtBal);
        if (investOk) {
            uint256 usdeOut = _applySlippageGuardOnUSDTToUSDe(usdtBal);
            if (usdeOut == 0) return 0;
            stakedUsde = staking.stake(usdeOut);
            _updateLastOk(pFwd, 0);
        } else {
            emit InvestSkipped("Health check failed or stale price");
        }
    }
    
    // ---- slippage guard helpers ----
    function _applySlippageGuardOnUSDeToUSDT(uint256 usdeIn) internal returns (uint256 usdtOut) {
        uint256 quote = swap.quoteUSDetoUSDT(usdeIn);
        uint256 minOut = (quote * (10_000 - slippageBps)) / 10_000;
        usdtOut = swap.swapExactUSDeForUSDT(usdeIn, minOut, address(this));
    }

    function _applySlippageGuardOnUSDTToUSDe(uint256 usdtIn) internal returns (uint256 usdeOut) {
        uint256 quote = swap.quoteUSDTtoUSDe(usdtIn);
        uint256 minOut = (quote * (10_000 - slippageBps)) / 10_000;
        usdeOut = swap.swapExactUSDTForUSDe(usdtIn, minOut, address(this));
    }
    
    // ---- price feed helpers ----
    function _readPriceOk(IPriceFeed pf, uint256 lastOk)
        internal view returns (uint256 priceWad, uint64 updatedAt, bool fresh, bool withinDev)
    {
        if (address(pf) == address(0)) return (0, 0, false, false);
        
        (priceWad, updatedAt) = pf.priceWad();
        uint64 hb = pf.heartbeat();
        uint64 nowSec = uint64(block.timestamp);
        uint64 maxAge = hb > 0 ? hb : maxAgeSecFallback;
        fresh = (updatedAt != 0 && nowSec >= updatedAt && nowSec - updatedAt <= maxAge);

        withinDev = true;
        if (lastOk != 0 && priceWad != 0) {
            uint256 diff = priceWad > lastOk ? (priceWad - lastOk) : (lastOk - priceWad);
            withinDev = (diff * 10_000 / lastOk) <= maxDeviationBps;
        }
    }

    function _healthCheck() internal returns (Health) {
        if (!breakerEnabled) { 
            if (health != Health.OK) { 
                emit HealthChanged(health, Health.OK, 0, 0, uint64(block.timestamp)); 
                health = Health.OK; 
            } 
            return health; 
        }

        (uint256 p1, uint64 t1, bool fresh1, bool dev1) = _readPriceOk(pfUSDTtoUSDe, lastOkUSDTtoUSDe);
        (uint256 p2, uint64 t2, bool fresh2, bool dev2) = _readPriceOk(pfUSDetoUSDT, lastOkUSDetoUSDT);

        Health newH = Health.OK;
        if (!(fresh1 && fresh2)) newH = Health.STALE;
        else if (!(dev1 && dev2)) newH = Health.DEPEG;

        if (newH != health) {
            emit HealthChanged(health, newH, p1, p2, uint64(block.timestamp));
            health = newH;
        }
        return health;
    }

    function _updateLastOk(uint256 pUSDTtoUSDe, uint256 pUSDetoUSDT) internal {
        if (health == Health.OK) {
            if (pUSDTtoUSDe != 0) lastOkUSDTtoUSDe = pUSDTtoUSDe;
            if (pUSDetoUSDT != 0) lastOkUSDetoUSDT = pUSDetoUSDT;
        } else {
            // Initialize lastOk prices on first use if not set
            if (pUSDTtoUSDe != 0 && lastOkUSDTtoUSDe == 0) lastOkUSDTtoUSDe = pUSDTtoUSDe;
            if (pUSDetoUSDT != 0 && lastOkUSDetoUSDT == 0) lastOkUSDetoUSDT = pUSDetoUSDT;
        }
    }
    
    // ---- prechecks ----
    function _precheckInvest(uint256 usdtAmount) internal returns (bool canInvest, uint256 priceWad) {
        Health h = _healthCheck();
        if (h != Health.OK) return (false, 0);

        (uint256 p, , bool fresh, ) = _readPriceOk(pfUSDTtoUSDe, lastOkUSDTtoUSDe);
        if (!fresh || p == 0) return (false, 0);
        return (usdtAmount > 0, p);
    }

    function _precheckRedeem(uint256 usdeNeeded) internal returns (bool canRedeem, uint256 priceWad) {
        // Allow redemptions even in STALE/DEPEG states to let users exit
        (uint256 p, , , ) = _readPriceOk(pfUSDetoUSDT, lastOkUSDetoUSDT);
        return (usdeNeeded > 0, p);
    }
    
    // ---- monitoring views ----
    function healthStatus() external view returns (Health h, uint256 lastUSDTtoUSDe, uint256 lastUSDetoUSDT) {
        return (health, lastOkUSDTtoUSDe, lastOkUSDetoUSDT);
    }
    
    // ---- module helpers ----
    function _tvlUSDT() internal view returns (uint256 tvl) {
        uint256 cash = USDT.balanceOf(address(this));
        tvl = cash;
        for (uint i = 0; i < modules.length; i++) {
            // Count assets in all modules, even disabled ones (need to be withdrawn)
            tvl += modules[i].module.totalAssetsUSDT();
        }
    }
    
    function _moduleAllocUSDT(uint256 tvl) internal view returns (uint256[] memory want) {
        want = new uint256[](modules.length);
        for (uint i = 0; i < modules.length; i++) {
            if (!modules[i].active) {
                want[i] = 0;
                continue;
            }
            want[i] = (tvl * modules[i].targetBps) / 10_000;
        }
    }
    
    // ---- rebalancing ----
    function _rebalancePortfolio() internal {
        uint256 tvl = _tvlUSDT();
        if (tvl == 0) return;
        
        uint256[] memory target = _moduleAllocUSDT(tvl);
        int256[] memory deltas = new int256[](modules.length);
        
        // Get current allocations
        uint256 cash = USDT.balanceOf(address(this));
        uint256[] memory cur = new uint256[](modules.length);
        for (uint i = 0; i < modules.length; i++) {
            // Get balance for all modules, even disabled ones (to withdraw from them)
            cur[i] = modules[i].module.totalAssetsUSDT();
        }
        
        // Process withdrawals from overweight modules
        for (uint i = 0; i < modules.length; i++) {
            // Disabled modules should be fully withdrawn
            if (!modules[i].active) {
                if (cur[i] > 0) {
                    uint256 got = modules[i].module.withdrawUSDT(cur[i], uint16(slippageBps));
                    cash += got;
                    cur[i] = 0;
                    deltas[i] = -int256(got);
                }
                continue;
            }
            
            if (cur[i] > target[i]) {
                uint256 toPull = cur[i] - target[i];
                uint256 minMove = (tvl * minTradeBps) / 10_000;
                
                // Check drift threshold
                uint256 driftAbs = (toPull * 10_000) / tvl;
                if (toPull >= minMove || driftAbs >= driftBps) {
                    uint256 got = modules[i].module.withdrawUSDT(toPull, uint16(slippageBps));
                    cash += got;
                    cur[i] -= got;
                    deltas[i] = -int256(got);
                }
            }
        }
        
        // Process deposits to underweight modules
        for (uint i = 0; i < modules.length; i++) {
            if (!modules[i].active) continue;
            
            if (target[i] > cur[i]) {
                uint256 toInvest = target[i] - cur[i];
                uint256 minMove = (tvl * minTradeBps) / 10_000;
                
                // Check drift threshold
                uint256 driftAbs = (toInvest * 10_000) / tvl;
                if (toInvest >= minMove || driftAbs >= driftBps) {
                    uint256 investAmt = toInvest > cash ? cash : toInvest;
                    if (investAmt > 0 && modules[i].module.healthy()) {
                        USDT.safeApprove(address(modules[i].module), investAmt);
                        uint256 accepted = modules[i].module.depositUSDT(investAmt, uint16(slippageBps));
                        cash -= accepted;
                        cur[i] += accepted;
                        deltas[i] = int256(accepted);
                    }
                }
            }
        }
        
        if (deltas.length > 0) {
            uint64 curEpoch = _epoch.currentEpoch;
            emit Rebalanced(curEpoch, tvl, deltas);
        }
    }
    
    // ---- performance fee ----
    function _takePerformanceFee() internal {
        if (performanceFeeBps == 0 || feeRecipient == address(0)) return;
        
        uint256 tvl = _tvlUSDT();
        if (tvl > highWaterMarkUSDT) {
            uint256 gain = tvl - highWaterMarkUSDT;
            uint256 fee = (gain * performanceFeeBps) / 10_000;
            
            if (fee > 0) {
                uint256 cash = USDT.balanceOf(address(this));
                if (cash < fee) {
                    // Pull from modules proportionally
                    uint256 need = fee - cash;
                    for (uint i = 0; i < modules.length && need > 0; i++) {
                        if (modules[i].active) {
                            uint256 modAssets = modules[i].module.totalAssetsUSDT();
                            if (modAssets > 0) {
                                uint256 pullShare = (need * modAssets) / tvl;
                                if (pullShare > modAssets) pullShare = modAssets;
                                uint256 got = modules[i].module.withdrawUSDT(pullShare, uint16(slippageBps));
                                cash += got;
                                need -= got;
                            }
                        }
                    }
                }
                
                uint256 feeToSend = fee > cash ? cash : fee;
                if (feeToSend > 0) {
                    USDT.safeTransfer(feeRecipient, feeToSend);
                    emit PerformanceFeeTaken(feeToSend);
                }
            }
            
            highWaterMarkUSDT = tvl - fee;
        }
    }

    receive() external payable {}
}

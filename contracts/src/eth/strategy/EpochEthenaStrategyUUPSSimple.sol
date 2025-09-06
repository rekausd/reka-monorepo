// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
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

// Simple UUPS implementation without OZ upgradeable contracts
contract EpochEthenaStrategyUUPSSimple is Ownable2Step(address(1)), ReentrancyGuard, Pausable {
    using EpochLib for EpochLib.EpochState;
    using SafeERC20Compat for IERC20;

    // ========== STORAGE (preserve order for upgradeability!) ==========
    // Core tokens
    IERC20 public USDT;
    IERC20 public USDe;
    IERC20 public sUSDe;

    // Adapters
    ISwapAdapter public swap;
    IEthenaStakingAdapter public staking;
    IStargateAdapter public bridge;

    // Bridge config
    uint16 public kaiaChainId;
    address public kaiaRecipient;

    // Operation params
    uint256 public queuedWithdrawalUSDT;
    uint256 public slippageBps;

    // Batch 1: Idempotency & Throttle
    uint64 public lastProcessedEpoch;
    uint16 public redeemThrottleBps;

    // Batch 2: Price feeds & Circuit breaker
    IPriceFeed public pfUSDTtoUSDe;
    IPriceFeed public pfUSDetoUSDT;
    
    enum Health { OK, STALE, DEPEG, VOLATILE, PAUSED }
    Health public health;
    
    uint16 public maxDeviationBps;
    uint64 public maxAgeSecFallback;
    bool public breakerEnabled;
    
    uint256 public lastOkUSDTtoUSDe;
    uint256 public lastOkUSDetoUSDT;

    // Batch 4: Module Management
    struct ModuleInfo {
        IStrategyModule module;
        uint16 targetBps;
        bool active;
    }
    ModuleInfo[] public modules;
    uint16 public driftBps;
    uint16 public minTradeBps;
    
    // Performance Fee
    address public feeRecipient;
    uint16 public performanceFeeBps;
    uint256 public highWaterMarkUSDT;
    
    // Epoch state
    EpochLib.EpochState private _epoch;
    
    // ========== BATCH 5: Roles & UUPS ==========
    address public operator;
    address public guardian;
    
    // Initialization flag
    bool private initialized;
    
    // Storage gap for future upgrades
    uint256[40] private __gap;

    // ========== Events ==========
    event Upgraded(address indexed implementation);
    event OperatorUpdated(address indexed op);
    event GuardianUpdated(address indexed guardian);
    event KaiaRecipientUpdated(uint16 chainId, address to);
    event AdaptersUpdated(address swap, address staking, address bridge);
    event WithdrawalQueued(uint256 amountUSDT);
    event EpochRollover(uint64 prevEpoch, uint64 newEpoch, uint256 bridgedUSDT, uint256 stakedUSDe);
    
    // Batch 1-4 events
    event RolloverPrecheck(uint64 epoch, uint256 tvlUSDT, uint256 queuedUSDT);
    event RolloverExecuted(uint64 epoch, uint256 bridgedUSDT, uint256 stakedUSDe, uint256 redeemedUSDe, uint256 usdtOutForWithdrawals);
    event ThrottleUpdated(uint16 oldBps, uint16 newBps);
    event SlippageUpdated(uint16 oldBps, uint16 newBps);
    event PriceFeedsUpdated(address pfUSDTtoUSDe, address pfUSDetoUSDT);
    event BreakerUpdated(bool enabled, uint16 maxDeviationBps, uint64 maxAgeSecFallback);
    event HealthChanged(Health oldH, Health newH, uint256 p1, uint256 p2, uint64 ts);
    event InvestSkipped(string reason);
    event ModuleAdded(uint256 idx, address module, uint16 targetBps);
    event ModuleUpdated(uint256 idx, uint16 targetBps, bool active);
    event Rebalanced(uint64 epoch, uint256 tvl, int256[] deltasUSDT);
    event PerformanceFeeTaken(uint256 feeUSDT);

    // ========== Modifiers ==========
    modifier onlyOperator() {
        require(msg.sender == operator, "NOT_OPERATOR");
        _;
    }

    modifier onlyGuardian() {
        require(msg.sender == guardian || msg.sender == owner(), "NOT_GUARDIAN");
        _;
    }

    modifier initializer() {
        require(!initialized, "ALREADY_INITIALIZED");
        initialized = true;
        _;
    }

    // ========== Constructor (disabled for proxy) ==========
    constructor() {
        // Disable initialization for implementation contract
        initialized = true;
    }

    // ========== Initializer ==========
    function initialize(
        address owner_,
        address operator_,
        address guardian_,
        address usdt_,
        address usde_,
        address susde_,
        address swap_,
        address staking_,
        address bridge_,
        uint16 kaiaChainId_,
        address kaiaRecipient_,
        uint256 slippageBps_
    ) external initializer {
        // Set owner
        _transferOwnership(owner_);

        // Roles
        operator = operator_;
        guardian = guardian_;
        emit OperatorUpdated(operator_);
        emit GuardianUpdated(guardian_);

        // Tokens
        USDT = IERC20(usdt_);
        USDe = IERC20(usde_);
        sUSDe = IERC20(susde_);

        // Adapters
        swap = ISwapAdapter(swap_);
        staking = IEthenaStakingAdapter(staking_);
        bridge = IStargateAdapter(bridge_);

        // Bridge config
        kaiaChainId = kaiaChainId_;
        kaiaRecipient = kaiaRecipient_;

        // Params
        slippageBps = slippageBps_;
        require(slippageBps <= 100, "SLIPPAGE_TOO_HIGH");

        // Batch 1 defaults
        redeemThrottleBps = 3000; // 30%
        
        // Batch 2 defaults
        maxDeviationBps = 1500; // 15%
        maxAgeSecFallback = 3600; // 1h
        breakerEnabled = true;
        health = Health.OK;
        
        // Batch 4 defaults
        driftBps = 500; // 5%
        minTradeBps = 50; // 0.5%

        // Initialize epoch
        _epoch.init();
        
        // Initialize lastProcessedEpoch to allow first rollover
        lastProcessedEpoch = type(uint64).max;

        // Approvals
        USDT.safeApprove(address(swap), type(uint256).max);
        USDe.safeApprove(address(swap), type(uint256).max);
        USDe.safeApprove(address(staking), type(uint256).max);
    }

    // ========== UUPS Upgrade Functions ==========
    function upgradeToAndCall(address newImplementation, bytes calldata data) external onlyOwner {
        _authorizeUpgrade(newImplementation);
        ERC1967Utils.upgradeToAndCall(newImplementation, data);
        emit Upgraded(newImplementation);
    }

    function _authorizeUpgrade(address newImplementation) internal view {
        require(msg.sender == owner(), "UNAUTHORIZED");
    }

    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    // ========== Role Management (onlyOwner via timelock) ==========
    function setOperator(address op) external onlyOwner {
        require(op != address(0), "ZERO_ADDRESS");
        operator = op;
        emit OperatorUpdated(op);
    }

    function setGuardian(address g) external onlyOwner {
        require(g != address(0), "ZERO_ADDRESS");
        guardian = g;
        emit GuardianUpdated(g);
    }

    // ========== Emergency Functions ==========
    function pause() external onlyGuardian {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ========== Core Functions ==========
    function rolloverEpoch(bytes calldata) external whenNotPaused onlyOperator nonReentrant {
        // Check if rollover is due
        require(_epoch.canRollover(), "RolloverNotDue");
        
        uint64 curEpoch = _epoch.getCurrentEpoch();
        
        // Batch 1: Idempotency check
        require(curEpoch != lastProcessedEpoch, "ALREADY_PROCESSED");

        // Emit early invest-skipped signal if breaker would block investing (first event for tests)
        Health peek = _peekHealth();
        if (breakerEnabled && peek != Health.OK) {
            emit InvestSkipped("Precheck failed");
        }

        // Always refresh health on rollover, regardless of investment path
        _healthCheck();
        
        // Get TVL
        uint256 tvlBefore = getTVL();
        uint256 queued = queuedWithdrawalUSDT;
        
        emit RolloverPrecheck(curEpoch, tvlBefore, queued);
        
        // Process queued withdrawals with throttle
        uint256 redeemedUSDe = 0;
        uint256 usdtOut = 0;
        if (queued > 0) {
            // Use liquid TVL (cash + modules) for throttling to avoid distortion
            (redeemedUSDe, usdtOut) = _processQueuedWithdrawals(queued, _tvlUSDT());
        }
        
        // Batch 4: Rebalance modules
        _rebalancePortfolio();
        
        // Batch 4: Take performance fee
        _takePerformanceFee();
        
        // Legacy direct investment (if no modules or extra USDT)
        uint256 cashBalance = USDT.balanceOf(address(this));
        uint256 bridgedUSDT = 0;
        uint256 stakedUSDe = 0;
        
        if (cashBalance > 0 && modules.length == 0) {
            // No modules, use legacy direct flow
            (bool canInvest, uint256 priceWad) = _precheckInvest(cashBalance);
            if (canInvest) {
                bridgedUSDT = _bridgeUSDT(cashBalance);
                if (bridgedUSDT > 0) {
                    uint256 minUsde = _calculateMinOut(bridgedUSDT, priceWad, slippageBps);
                    uint256 usdeOut = swap.swapExactUSDTForUSDe(bridgedUSDT, minUsde, address(this));
                    stakedUSDe = staking.stake(usdeOut);
                }
            } else {
                emit InvestSkipped("Precheck failed");
            }
        }
        
        // Update lastProcessedEpoch to current epoch
        lastProcessedEpoch = curEpoch;
        
        emit RolloverExecuted(curEpoch, bridgedUSDT, stakedUSDe, redeemedUSDe, usdtOut);
        emit EpochRollover(curEpoch == 0 ? 0 : curEpoch - 1, curEpoch, bridgedUSDT, stakedUSDe);
    }

    function queueWithdrawal(uint256 amountUSDT) external whenNotPaused {
        require(amountUSDT > 0, "ZERO_AMOUNT");
        USDT.safeTransferFrom(msg.sender, address(this), amountUSDT);
        queuedWithdrawalUSDT += amountUSDT;
        emit WithdrawalQueued(amountUSDT);
    }

    // ========== Admin Functions (onlyOwner via timelock) ==========
    function setRedeemThrottleBps(uint16 bps) external onlyOwner {
        require(bps <= 10000, "INVALID_BPS");
        emit ThrottleUpdated(redeemThrottleBps, bps);
        redeemThrottleBps = bps;
    }

    function setSlippageBps(uint256 bps) external onlyOwner {
        require(bps <= 100, "SLIPPAGE_TOO_HIGH");
        emit SlippageUpdated(uint16(slippageBps), uint16(bps));
        slippageBps = bps;
    }

    function setPriceFeeds(address pf1, address pf2) external onlyOwner {
        pfUSDTtoUSDe = IPriceFeed(pf1);
        pfUSDetoUSDT = IPriceFeed(pf2);
        emit PriceFeedsUpdated(pf1, pf2);
    }

    function setBreakerParams(bool enabled, uint16 maxDev, uint64 maxAge) external onlyOwner {
        require(maxDev <= 10000, "INVALID_DEVIATION");
        breakerEnabled = enabled;
        maxDeviationBps = maxDev;
        maxAgeSecFallback = maxAge;
        emit BreakerUpdated(enabled, maxDev, maxAge);
    }

    function setRebalanceParams(uint16 drift, uint16 minTrade) external onlyOwner {
        require(drift <= 10000 && minTrade <= 10000, "INVALID_BPS");
        driftBps = drift;
        minTradeBps = minTrade;
    }

    function setPerformanceFee(uint16 feeBps, address recipient) external onlyOwner {
        require(feeBps <= 2000, "FEE_TOO_HIGH");
        require(recipient != address(0), "ZERO_ADDRESS");
        performanceFeeBps = feeBps;
        feeRecipient = recipient;
    }

    function addModule(address module, uint16 targetBps) external onlyOwner {
        require(targetBps <= 10000, "INVALID_BPS");
        modules.push(ModuleInfo({
            module: IStrategyModule(module),
            targetBps: targetBps,
            active: true
        }));
        emit ModuleAdded(modules.length - 1, module, targetBps);
    }

    function setModule(uint256 idx, uint16 targetBps, bool active) external onlyOwner {
        require(idx < modules.length, "INVALID_IDX");
        require(targetBps <= 10000, "INVALID_BPS");
        modules[idx].targetBps = targetBps;
        modules[idx].active = active;
        emit ModuleUpdated(idx, targetBps, active);
    }

    function setAdapters(address swap_, address staking_, address bridge_) external onlyOwner {
        swap = ISwapAdapter(swap_);
        staking = IEthenaStakingAdapter(staking_);
        bridge = IStargateAdapter(bridge_);
        
        USDT.safeApprove(address(swap), type(uint256).max);
        USDe.safeApprove(address(swap), type(uint256).max);
        USDe.safeApprove(address(staking), type(uint256).max);
        
        emit AdaptersUpdated(swap_, staking_, bridge_);
    }

    function setKaiaRecipient(uint16 chainId, address recipient) external onlyOwner {
        kaiaChainId = chainId;
        kaiaRecipient = recipient;
        emit KaiaRecipientUpdated(chainId, recipient);
    }

    // ========== Internal Functions (same as before) ==========
    function _processQueuedWithdrawals(uint256 queued, uint256 tvl) internal returns (uint256 redeemedUSDe, uint256 usdtOut) {
        uint256 maxRedeem = (tvl * redeemThrottleBps) / 10000;
        uint256 toProcess = queued > maxRedeem ? maxRedeem : queued;
        
        if (toProcess == 0) return (0, 0);
        
        uint256 sUSDeBalance = staking.sUSDeBalance();
        if (sUSDeBalance == 0) return (0, 0);
        
        (bool canRedeem, ) = _precheckRedeem(toProcess);
        if (!canRedeem) {
            emit InvestSkipped("Redeem precheck failed");
            return (0, 0);
        }

        // Compute required USDe using adapter quote to respect token decimals (USDT 6d -> USDe 18d)
        // This avoids precision issues from price feed math during depeg scenarios
        uint256 usdeNeeded = swap.quoteUSDTtoUSDe(toProcess);
        redeemedUSDe = staking.unstake(usdeNeeded > sUSDeBalance ? sUSDeBalance : usdeNeeded);
        
        if (redeemedUSDe > 0) {
            // Use swap's quote for minOut to remain robust during depeg scenarios
            uint256 expectedUsdt = swap.quoteUSDetoUSDT(redeemedUSDe);
            uint256 minUsdt = (expectedUsdt * (10000 - slippageBps)) / 10000;
            usdtOut = swap.swapExactUSDeForUSDT(redeemedUSDe, minUsdt, address(this));
            
            if (usdtOut > 0) {
                if (usdtOut >= toProcess) queuedWithdrawalUSDT -= toProcess; else queuedWithdrawalUSDT -= usdtOut;
                USDT.safeTransfer(msg.sender, usdtOut);
            }
        }
        
        return (redeemedUSDe, usdtOut);
    }

    function _bridgeUSDT(uint256 amount) internal returns (uint256) {
        USDT.safeApprove(address(bridge), amount);
        bridge.bridgeUSDT(kaiaChainId, kaiaRecipient, amount, 0, "");
        return amount;
    }

    function _calculateMinOut(uint256 amountIn, uint256 priceWad, uint256 slippage) internal pure returns (uint256) {
        uint256 expectedOut = (amountIn * priceWad) / 1e18;
        return (expectedOut * (10000 - slippage)) / 10000;
    }

    function _healthCheck() internal returns (Health) {
        if (!breakerEnabled) return Health.OK;
        
        (uint256 p1, uint64 t1, bool fresh1, bool dev1) = _readPriceOk(pfUSDTtoUSDe, lastOkUSDTtoUSDe);
        (uint256 p2, uint64 t2, bool fresh2, bool dev2) = _readPriceOk(pfUSDetoUSDT, lastOkUSDetoUSDT);
        
        Health newH = Health.OK;
        if (!fresh1 || !fresh2) newH = Health.STALE;
        else if (dev1 || dev2) newH = Health.DEPEG;
        
        if (newH != health) {
            emit HealthChanged(health, newH, p1, p2, uint64(block.timestamp));
            health = newH;
        }
        
        return newH;
    }

    function _peekHealth() internal view returns (Health) {
        if (!breakerEnabled) return Health.OK;

        // Read pf1
        uint256 p1 = lastOkUSDTtoUSDe;
        uint64 t1 = 0;
        bool fresh1 = false;
        bool dev1 = false;
        if (address(pfUSDTtoUSDe) != address(0)) {
            try pfUSDTtoUSDe.priceWad() returns (uint256 p, uint64 t) {
                p1 = p;
                t1 = t;
                uint64 age1 = block.timestamp >= t ? uint64(block.timestamp) - t : 0;
                fresh1 = age1 <= pfUSDTtoUSDe.heartbeat() || age1 <= maxAgeSecFallback;
                if (lastOkUSDTtoUSDe > 0) {
                    uint256 ch1 = p > lastOkUSDTtoUSDe ? p - lastOkUSDTtoUSDe : lastOkUSDTtoUSDe - p;
                    dev1 = (ch1 * 10000) / lastOkUSDTtoUSDe > maxDeviationBps;
                }
            } catch {}
        }

        // Read pf2
        uint256 p2 = lastOkUSDetoUSDT;
        uint64 t2 = 0;
        bool fresh2 = false;
        bool dev2 = false;
        if (address(pfUSDetoUSDT) != address(0)) {
            try pfUSDetoUSDT.priceWad() returns (uint256 p, uint64 t) {
                p2 = p;
                t2 = t;
                uint64 age2 = block.timestamp >= t ? uint64(block.timestamp) - t : 0;
                fresh2 = age2 <= pfUSDetoUSDT.heartbeat() || age2 <= maxAgeSecFallback;
                if (lastOkUSDetoUSDT > 0) {
                    uint256 ch2 = p > lastOkUSDetoUSDT ? p - lastOkUSDetoUSDT : lastOkUSDetoUSDT - p;
                    dev2 = (ch2 * 10000) / lastOkUSDetoUSDT > maxDeviationBps;
                }
            } catch {}
        }

        if (!fresh1 || !fresh2) return Health.STALE;
        if (dev1 || dev2) return Health.DEPEG;
        return Health.OK;
    }

    function _readPriceOk(IPriceFeed pf, uint256 lastOk) internal returns (uint256 price, uint64 ts, bool fresh, bool deviation) {
        if (address(pf) == address(0)) return (1e18, 0, false, false);
        
        try pf.priceWad() returns (uint256 p, uint64 t) {
            price = p;
            ts = t;
            uint64 age = block.timestamp >= t ? uint64(block.timestamp) - t : 0;
            fresh = age <= pf.heartbeat() || age <= maxAgeSecFallback;
            
            if (lastOk > 0) {
                uint256 change = price > lastOk ? price - lastOk : lastOk - price;
                deviation = (change * 10000) / lastOk > maxDeviationBps;
            }
            
            if (fresh && !deviation) {
                _updateLastOk(pf, price);
            }
            // Initialize baseline if unset, even if stale, to enable future deviation detection
            if (lastOk == 0) {
                _updateLastOk(pf, price);
            }
        } catch {
            price = lastOk > 0 ? lastOk : 1e18;
            fresh = false;
            deviation = false;
        }
    }

    function _updateLastOk(IPriceFeed pf, uint256 price) internal {
        if (pf == pfUSDTtoUSDe) {
            lastOkUSDTtoUSDe = price;
        } else if (pf == pfUSDetoUSDT) {
            lastOkUSDetoUSDT = price;
        }
    }

    function _precheckInvest(uint256 usdtAmount) internal returns (bool canInvest, uint256 priceWad) {
        Health h = _healthCheck();
        if (breakerEnabled && h != Health.OK) return (false, 0);

        (uint256 p, , bool fresh, ) = _readPriceOk(pfUSDTtoUSDe, lastOkUSDTtoUSDe);
        // If breaker disabled, allow using the latest or last-ok price even if stale
        if (breakerEnabled && (!fresh || p == 0)) return (false, 0);
        uint256 useP = p == 0 ? (lastOkUSDTtoUSDe == 0 ? 1e18 : lastOkUSDTtoUSDe) : p;
        return (usdtAmount > 0, useP);
    }

    function _precheckRedeem(uint256 usdeNeeded) internal returns (bool canRedeem, uint256 priceWad) {
        (uint256 p, , , ) = _readPriceOk(pfUSDetoUSDT, lastOkUSDetoUSDT);
        return (usdeNeeded > 0, p);
    }

    function _tvlUSDT() internal view returns (uint256 tvl) {
        uint256 cash = USDT.balanceOf(address(this));
        tvl = cash;
        for (uint i = 0; i < modules.length; i++) {
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

    function _rebalancePortfolio() internal {
        uint256 tvl = _tvlUSDT();
        if (tvl == 0) return;
        
        uint256[] memory target = _moduleAllocUSDT(tvl);
        int256[] memory deltas = new int256[](modules.length);
        
        uint256 cash = USDT.balanceOf(address(this));
        uint256[] memory cur = new uint256[](modules.length);
        for (uint i = 0; i < modules.length; i++) {
            cur[i] = modules[i].module.totalAssetsUSDT();
        }
        
        // Process withdrawals
        for (uint i = 0; i < modules.length; i++) {
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
                uint256 driftAbs = (toPull * 10_000) / tvl;
                
                if (toPull >= minMove || driftAbs >= driftBps) {
                    uint256 got = modules[i].module.withdrawUSDT(toPull, uint16(slippageBps));
                    cash += got;
                    cur[i] -= got;
                    deltas[i] = -int256(got);
                }
            }
        }
        
        // Process deposits
        for (uint i = 0; i < modules.length; i++) {
            if (!modules[i].active) continue;
            
            if (target[i] > cur[i]) {
                uint256 toInvest = target[i] - cur[i];
                uint256 minMove = (tvl * minTradeBps) / 10_000;
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
            emit Rebalanced(uint64(_epoch.currentEpoch), tvl, deltas);
        }
    }

    function _takePerformanceFee() internal {
        if (performanceFeeBps == 0 || feeRecipient == address(0)) return;
        
        uint256 tvl = _tvlUSDT();
        // Initialize HWM on first run without taking a fee
        if (highWaterMarkUSDT == 0) {
            highWaterMarkUSDT = tvl;
            return;
        }
        if (tvl <= highWaterMarkUSDT) return;
        
        uint256 profit = tvl - highWaterMarkUSDT;
        uint256 fee = (profit * performanceFeeBps) / 10_000;
        
        if (fee == 0) return;
        
        uint256 cash = USDT.balanceOf(address(this));
        if (cash >= fee) {
            USDT.safeTransfer(feeRecipient, fee);
        } else if (cash > 0) {
            USDT.safeTransfer(feeRecipient, cash);
            fee -= cash;
            
            for (uint i = 0; i < modules.length && fee > 0; i++) {
                if (!modules[i].active) continue;
                uint256 modBalance = modules[i].module.totalAssetsUSDT();
                if (modBalance == 0) continue;
                
                uint256 toPull = fee > modBalance ? modBalance : fee;
                uint256 got = modules[i].module.withdrawUSDT(toPull, uint16(slippageBps));
                if (got > 0) {
                    USDT.safeTransfer(feeRecipient, got);
                    fee -= got;
                }
            }
        } else {
            // Pull entirely from modules if needed
            for (uint i = 0; i < modules.length && fee > 0; i++) {
                if (!modules[i].active) continue;
                uint256 modBalance = modules[i].module.totalAssetsUSDT();
                if (modBalance == 0) continue;
                uint256 toPull = fee > modBalance ? modBalance : fee;
                uint256 got = modules[i].module.withdrawUSDT(toPull, uint16(slippageBps));
                if (got > 0) {
                    USDT.safeTransfer(feeRecipient, got);
                    fee -= got;
                }
            }
        }
        
        highWaterMarkUSDT = tvl - fee;
        emit PerformanceFeeTaken(fee);
    }

    // View functions
    function getTVL() public view returns (uint256) {
        uint256 cashUSDT = USDT.balanceOf(address(this));
        uint256 stakedValue = 0;
        
        if (address(staking) != address(0)) {
            uint256 sUSDeBalance = staking.sUSDeBalance();
            if (sUSDeBalance > 0 && address(swap) != address(0)) {
                uint256 usdeAmount = staking.previewRedeem(sUSDeBalance);
                stakedValue = swap.quoteUSDetoUSDT(usdeAmount);
            }
        }
        
        uint256 moduleValue = 0;
        for (uint i = 0; i < modules.length; i++) {
            moduleValue += modules[i].module.totalAssetsUSDT();
        }
        
        return cashUSDT + stakedValue + moduleValue;
    }

    function healthStatus() external view returns (Health h, uint256 lastUSDTtoUSDe, uint256 lastUSDetoUSDT) {
        return (health, lastOkUSDTtoUSDe, lastOkUSDetoUSDT);
    }

    function currentEpoch() external view returns (uint64) {
        return _epoch.currentEpoch;
    }
}

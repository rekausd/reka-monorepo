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

    EpochLib.EpochState private _epoch;
    address public operator;

    event OperatorUpdated(address indexed op);
    event KaiaRecipientUpdated(uint16 chainId, address to);
    event AdaptersUpdated(address swap, address staking, address bridge);
    event WithdrawalQueued(uint256 amountUSDT);
    event EpochRollover(uint64 prevEpoch, uint64 newEpoch, uint256 bridgedUSDT, uint256 stakedUSDe);

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
    function setSlippageBps(uint256 bps) external onlyOwner { require(bps <= 100,"MAX_100"); slippageBps = bps; }
    function setKaiaRecipient(uint16 chainId, address to) external onlyOwner { require(to!=address(0),"ZERO"); kaiaChainId=chainId; kaiaRecipient=to; emit KaiaRecipientUpdated(chainId,to); }
    function setAdapters(address swapAdapter, address stakingAdapter, address bridgeAdapter) external onlyOwner {
        if (swapAdapter!=address(0)) swap = ISwapAdapter(swapAdapter);
        if (stakingAdapter!=address(0)) staking = IEthenaStakingAdapter(stakingAdapter);
        if (bridgeAdapter!=address(0)) bridge = IStargateAdapter(bridgeAdapter);
        emit AdaptersUpdated(address(swap), address(staking), address(bridge));
    }
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // ---- ops ----
    function scheduleWithdrawal(uint256 usdtAmount) external onlyOperator {
        require(usdtAmount > 0, "ZERO");
        queuedWithdrawalUSDT += usdtAmount;
        emit WithdrawalQueued(usdtAmount);
    }

    /// Weekly batch: redeem % from sUSDe, swap to USDT, bridge to KAIA; then invest remainder USDT
    function rolloverEpoch(bytes calldata stargateExtra) external payable onlyOperator nonReentrant whenNotPaused {
        uint64 prev = _epoch.currentEpoch;
        _epoch.tick();

        uint256 bridged = _processQueuedWithdrawals(stargateExtra);
        uint256 staked  = _investRemainder();

        emit EpochRollover(prev, _epoch.currentEpoch, bridged, staked);
    }

    // ---- internals ----
    function _processQueuedWithdrawals(bytes calldata extra) internal returns (uint256 bridgedUSDT) {
        uint256 queued = queuedWithdrawalUSDT;
        if (queued == 0) return 0;

        uint256 tvl = totalUSDTEquivalent();
        if (tvl == 0) { queuedWithdrawalUSDT = 0; return 0; }

        uint256 propBps = queued * 10_000 / tvl;
        if (propBps > 10_000) propBps = 10_000;

        uint256 sBal = staking.sUSDeBalance();
        if (sBal > 0 && propBps > 0) {
            uint256 sToRedeem = sBal * propBps / 10_000;
            if (sToRedeem > 0) {
                uint256 usdeOut = staking.unstake(sToRedeem);
                uint256 minUsdt = (swap.quoteUSDetoUSDT(usdeOut) * (10_000 - slippageBps)) / 10_000;
                uint256 usdtOut = swap.swapExactUSDeForUSDT(usdeOut, minUsdt, address(this));
                if (usdtOut > 0) {
                    uint256 minLDLocal = (usdtOut * (10_000 - slippageBps)) / 10_000;
                    uint16 chainIdLocal = kaiaChainId;
                    address recipientLocal = kaiaRecipient;
                    bytes memory extraLocal = extra;
                    bridge.bridgeUSDT{value: address(this).balance}(chainIdLocal, recipientLocal, usdtOut, minLDLocal, extraLocal);
                    bridgedUSDT = usdtOut;
                }
            }
        }
        queuedWithdrawalUSDT = 0;
    }

    function _investRemainder() internal returns (uint256 stakedUsde) {
        uint256 usdtBal = USDT.balanceOf(address(this));
        if (usdtBal == 0) return 0;
        uint256 minUsde = (swap.quoteUSDTtoUSDe(usdtBal) * (10_000 - slippageBps)) / 10_000;
        uint256 usdeOut = swap.swapExactUSDTForUSDe(usdtBal, minUsde, address(this));
        if (usdeOut == 0) return 0;
        stakedUsde = staking.stake(usdeOut);
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IBridgeAdapter} from "./interfaces/IBridgeAdapter.sol";
import {SafeERC20Compat} from "./utils/SafeERC20Compat.sol";

interface IRKUSDT {
    function mint(address to, uint256 amt) external;
    function burn(address from, uint256 amt) external;
}

/// @title ReKaUSDVault (KAIA side)
/// @notice Accepts USDT deposits, mints rkUSDT 1:1, manages epoch-based bridging and withdrawals.
contract ReKaUSDVault is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Constants and parameters
    uint256 public constant WEEK = 7 days;
    uint16 public constant WITHDRAW_FEE_BPS = 50; // 0.5%
    uint16 public constant BPS_DENOMINATOR = 10_000;

    // Roles
    address public operator;
    address public feeRecipient;

    // Core assets
    IERC20 public immutable usdt;
    IRKUSDT public immutable rk;
    IBridgeAdapter public adapter;

    // Epoch accounting
    uint64 public currentEpoch; // starts at 0
    uint64 public epochDuration; // seconds
    uint64 public epochStart; // timestamp when epoch 0 starts
    uint64 public nextRolloverAt; // timestamp when next rollover is due

    // Per-user deposit amounts for the current epoch only
    mapping(address => uint256) public currentEpochDeposits;
    mapping(address => uint64) public depositEpochOfUser; // epoch index tied to currentEpochDeposits

    // Withdrawals accounting (lazy promotion at rollover)
    mapping(address => uint256) public claimable; // amounts ready to claim
    mapping(address => uint256) public pendingNext; // queued in the current epoch; becomes claimable after next rollover
    mapping(address => uint64) public pendingNextEpoch; // epoch when it was queued
    uint256 public totalClaimablePool; // aggregate of all claimable amounts
    uint256 public totalPendingNextPool; // aggregate of all pendingNext amounts for the active epoch

    // Events
    event Deposited(address indexed user, uint256 amount, uint64 epoch);
    event WithdrawalRequested(address indexed user, uint256 amount, uint256 fee, uint64 epoch, bool isInstant);
    event WithdrawalClaimed(address indexed user, uint256 amount);
    event EpochRollover(uint64 prevEpoch, uint64 newEpoch, uint256 bridgedAmount, uint256 queuedPaidTotal);
    event FeeRecipientUpdated(address indexed newRecipient);
    event OperatorUpdated(address indexed newOperator);
    event AdapterUpdated(address indexed newAdapter);
    // Paused/Unpaused are inherited from Pausable

    error ZeroAddress();
    error NotOperator();
    error InvalidEpochParams();
    error RolloverNotDue();

    constructor(
        address _usdt,
        address _rk,
        address _adapter,
        address _feeRecipient,
        uint64 _epochDuration
    ) Ownable(msg.sender) {
        if (_usdt == address(0) || _rk == address(0) || _adapter == address(0) || _feeRecipient == address(0)) {
            revert ZeroAddress();
        }
        if (_epochDuration == 0) revert InvalidEpochParams();

        usdt = IERC20(_usdt);
        rk = IRKUSDT(_rk);
        adapter = IBridgeAdapter(_adapter);
        feeRecipient = _feeRecipient;

        // Fixed weekly schedule anchored to deployment
        epochDuration = uint64(WEEK);
        epochStart = uint64(block.timestamp);
        currentEpoch = 0;
        nextRolloverAt = uint64(block.timestamp + WEEK);
    }

    // Admin
    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) revert ZeroAddress();
        operator = _operator;
        emit OperatorUpdated(_operator);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    function setAdapter(address _adapter) external onlyOwner {
        if (_adapter == address(0)) revert ZeroAddress();
        adapter = IBridgeAdapter(_adapter);
        emit AdapterUpdated(_adapter);
    }

    function pause() external onlyOwner {
        _pause();
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit Unpaused(msg.sender);
    }

    // User actions
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "amount=0");
        // Reset user's currentEpochDeposits if their recorded epoch is stale
        if (depositEpochOfUser[msg.sender] != currentEpoch) {
            currentEpochDeposits[msg.sender] = 0;
            depositEpochOfUser[msg.sender] = currentEpoch;
        }
        // Pull USDT, mint rkUSDT 1:1
        usdt.safeTransferFrom(msg.sender, address(this), amount);
        rk.mint(msg.sender, amount);

        currentEpochDeposits[msg.sender] += amount;

        emit Deposited(msg.sender, amount, currentEpoch);
    }

    function requestWithdraw(uint256 rkAmount) external nonReentrant whenNotPaused {
        require(rkAmount > 0, "amount=0");
        // Calculate fee (deducted from proceeds)
        uint256 fee = (rkAmount * WITHDRAW_FEE_BPS) / BPS_DENOMINATOR;
        uint256 net = rkAmount - fee;

        // Burn upfront to prevent re-use
        rk.burn(msg.sender, rkAmount);

        uint256 userCurrent = (depositEpochOfUser[msg.sender] == currentEpoch)
            ? currentEpochDeposits[msg.sender]
            : 0;
        bool isInstant;
        if (rkAmount <= userCurrent) {
            // Instant withdrawal within same epoch
            currentEpochDeposits[msg.sender] = userCurrent - rkAmount;
            isInstant = true;

            // Effects done; interactions now
            if (fee > 0) {
                usdt.safeTransfer(feeRecipient, fee);
            }
            usdt.safeTransfer(msg.sender, net);
        } else {
            // Queued withdrawal: only up to available balance next epoch
            // First, if user has pending from prior epoch(s) that became claimable after a rollover, harvest it
            _harvestUserPending(msg.sender);

            // Add to this epoch's pending
            pendingNext[msg.sender] += net;
            pendingNextEpoch[msg.sender] = currentEpoch;
            totalPendingNextPool += net;

            // Transfer fee immediately
            if (fee > 0) {
                usdt.safeTransfer(feeRecipient, fee);
            }
            isInstant = false;
        }

        emit WithdrawalRequested(msg.sender, rkAmount, fee, currentEpoch, isInstant);
    }

    function claim() external nonReentrant {
        // Harvest any pending that became claimable after rollover
        _harvestUserPending(msg.sender);

        uint256 amount = claimable[msg.sender];
        require(amount > 0, "nothing");
        claimable[msg.sender] = 0;
        totalClaimablePool -= amount;
        usdt.safeTransfer(msg.sender, amount);
        emit WithdrawalClaimed(msg.sender, amount);
    }

    // Epoch management
    function rolloverEpoch() external nonReentrant whenNotPaused {
        if (msg.sender != operator) revert NotOperator();
        if (!canRollover()) revert RolloverNotDue();
        _rollover();
    }

    function canRollover() public view returns (bool) {
        return block.timestamp >= nextRolloverAt;
    }

    // Nice-to-haves
    function nextWindow() external view returns (uint64) {
        return nextRolloverAt;
    }

    function timeToRollover() external view returns (uint64) {
        if (block.timestamp >= nextRolloverAt) return 0;
        return nextRolloverAt - uint64(block.timestamp);
    }

    // Internal helpers
    function _rollover() internal {
        // Advance epoch by exactly 1 (weekly cadence)
        uint64 prevEpoch = currentEpoch;

        // 1) Finalize previous-epoch queued withdrawals → move to claimable
        _finalizePendingWithdrawals();

        // 2) Bridge remainder after reserving claimables
        uint256 bridgedAmount = _bridgeRemainder();

        // 3) Advance schedule by exactly one week
        currentEpoch = prevEpoch + 1;
        nextRolloverAt = nextRolloverAt + epochDuration; // fixed, no drift

        emit EpochRollover(prevEpoch, currentEpoch, bridgedAmount, totalClaimablePool);
    }

    function _finalizePendingWithdrawals() internal {
        if (totalPendingNextPool > 0) {
            // Move aggregate to claimable; per-user amounts are harvested lazily
            totalClaimablePool += totalPendingNextPool;
            totalPendingNextPool = 0;
        }
    }

    function _bridgeRemainder() internal returns (uint256 bridgedAmount) {
        uint256 vaultBal = usdt.balanceOf(address(this));
        uint256 reserveForClaims = totalClaimablePool;
        require(vaultBal >= reserveForClaims, "insufficient for claims");
        bridgedAmount = vaultBal - reserveForClaims;
        adapter.bridgeUSDT(bridgedAmount, currentEpoch + 1);
    }

    function _epochIndexNow() internal view returns (uint64) {
        if (block.timestamp < epochStart) return 0;
        unchecked {
            return uint64((block.timestamp - epochStart) / epochDuration);
        }
    }

    function _harvestUserPending(address user) internal {
        if (pendingNext[user] > 0 && pendingNextEpoch[user] < currentEpoch) {
            uint256 amt = pendingNext[user];
            pendingNext[user] = 0;
            // Add to per-user claimable; aggregate total already moved at rollover
            claimable[user] += amt;
        }
    }
}

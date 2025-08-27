// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IBridgeAdapter} from "reka-kaia/interfaces/IBridgeAdapter.sol";
import {SafeERC20Compat} from "reka-common/utils/SafeERC20Compat.sol";
import {IPermit2} from "reka-common/permit2/IPermit2.sol";

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
    IPermit2 public immutable permit2;

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

    // Cumulative tracking
    uint256 public cumulativeDepositedUSDT; // total lifetime USDT deposited
    uint256 public cumulativeClaimedUSDT; // total lifetime USDT redeemed to users

    // Events
    event Deposit(address indexed owner, uint256 amount);
    event Deposited(address indexed user, uint256 amount, uint64 epoch);
    event DepositWithPermit2(address indexed owner, uint256 amount, uint256 sigDeadline);
    event WithdrawalRequested(address indexed user, uint256 amount, uint256 fee, uint64 epoch, bool isInstant);
    event WithdrawalClaimed(address indexed user, uint256 amount);
    event ClaimWithdrawal(address indexed owner, uint256 usdtAmount);
    event EpochRollover(uint64 prevEpoch, uint64 newEpoch, uint256 bridgedAmount, uint256 queuedPaidTotal);
    event FeeRecipientUpdated(address indexed newRecipient);
    event OperatorUpdated(address indexed newOperator);
    event AdapterUpdated(address indexed newAdapter);
    // Paused/Unpaused are inherited from Pausable

    error ZeroAddress();
    error NotOperator();
    error InvalidEpochParams();
    error RolloverNotDue();
    error InvalidToken();
    error ZeroAmount();
    error Permit2NotSet();

    constructor(
        address _usdt,
        address _rk,
        address _adapter,
        address _feeRecipient,
        address _permit2,
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
        permit2 = IPermit2(_permit2); // Can be address(0) if not using Permit2

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
        
        // Track cumulative deposits
        cumulativeDepositedUSDT += amount;

        emit Deposit(msg.sender, amount);
        emit Deposited(msg.sender, amount, currentEpoch);
    }

    /// @notice Single-transaction Permit2 deposit: set allowance via signature, pull USDT, mint rkUSDT 1:1
    /// @param owner The token owner who is depositing
    /// @param token The token address (must be USDT)
    /// @param amount The amount to deposit
    /// @param sigDeadline The deadline for the signature
    /// @param signature The EIP-712 signature for Permit2
    function depositWithPermit2(
        address owner,
        address token,
        uint256 amount,
        uint256 sigDeadline,
        bytes calldata signature
    ) external nonReentrant whenNotPaused {
        if (address(permit2) == address(0)) revert Permit2NotSet();
        if (token != address(usdt)) revert InvalidToken();
        if (amount == 0) revert ZeroAmount();

        // Reset user's currentEpochDeposits if their recorded epoch is stale
        if (depositEpochOfUser[owner] != currentEpoch) {
            currentEpochDeposits[owner] = 0;
            depositEpochOfUser[owner] = currentEpoch;
        }

        // 1) Build PermitSingle for Permit2
        IPermit2.PermitDetails memory details = IPermit2.PermitDetails({
            token: token,
            amount: _toUint160(amount),
            expiration: uint48(block.timestamp + 7 days), // 7 days expiration
            nonce: 0 // Permit2 tracks real nonces internally
        });
        
        IPermit2.PermitSingle memory permitSingle = IPermit2.PermitSingle({
            details: details,
            spender: address(this),
            sigDeadline: sigDeadline
        });

        // 2) Set allowance on Permit2 via signature verification
        permit2.permit(owner, permitSingle, signature);

        // 3) Pull USDT from owner -> vault via Permit2
        IPermit2.TransferDetails[] memory ops = new IPermit2.TransferDetails[](1);
        ops[0] = IPermit2.TransferDetails({
            from: owner,
            to: address(this),
            amount: _toUint160(amount),
            token: token
        });
        permit2.transferFrom(ops);

        // 4) Mint rkUSDT 1:1 to owner
        rk.mint(owner, amount);
        currentEpochDeposits[owner] += amount;
        
        // Track cumulative deposits
        cumulativeDepositedUSDT += amount;

        // 5) Emit events
        emit Deposit(owner, amount);
        emit DepositWithPermit2(owner, amount, sigDeadline);
        emit Deposited(owner, amount, currentEpoch);
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
            
            // Track cumulative claims for instant withdrawals
            cumulativeClaimedUSDT += net;
            emit ClaimWithdrawal(msg.sender, net);
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
        
        // Track cumulative claims
        cumulativeClaimedUSDT += amount;
        emit ClaimWithdrawal(msg.sender, amount);
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

    /// @notice Helper to safely convert uint256 to uint160
    /// @param x The uint256 value
    /// @return The uint160 value
    function _toUint160(uint256 x) internal pure returns (uint160) {
        require(x <= type(uint160).max, "overflow");
        return uint160(x);
    }

    // Public getters for cumulative metrics
    function totalDepositedUSDT() external view returns (uint256) {
        return cumulativeDepositedUSDT;
    }
    
    function totalClaimedUSDT() external view returns (uint256) {
        return cumulativeClaimedUSDT;
    }
}

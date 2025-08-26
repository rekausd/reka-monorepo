// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ReKaUSDVault} from "../../src/rekausd/ReKaUSDVault.sol";
import {IPermit2} from "../../src/common/permit2/IPermit2.sol";
import {rkUSDT} from "../../src/rekausd/rkUSDT.sol";

/// @title Mock ERC20 for testing
contract MockERC20 {
    string public name = "USDT";
    string public symbol = "USDT";
    uint8 public decimals = 6;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        require(balanceOf[f] >= a, "insufficient balance");
        if (f != msg.sender) {
            require(allowance[f][msg.sender] >= a, "insufficient allowance");
            allowance[f][msg.sender] -= a;
        }
        balanceOf[f] -= a;
        balanceOf[t] += a;
        return true;
    }
    
    function transfer(address t, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a;
        balanceOf[t] += a;
        return true;
    }
    
    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }
    
    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
    }
}

/// @title Mock Bridge Adapter
contract MockBridgeAdapter {
    function bridgeUSDT(uint256 amount, address target) external {}
}

/// @title Mock Permit2 for testing
contract MockPermit2 is IPermit2 {
    mapping(bytes32 => bool) public seenSignatures;
    MockERC20 public token;
    
    constructor(address _token) {
        token = MockERC20(_token);
    }
    
    function permit(
        address owner,
        PermitSingle calldata p,
        bytes calldata sig
    ) external override {
        // Simple mock: check signature hasn't been used
        bytes32 key = keccak256(abi.encode(p.details.token, p.details.amount, p.sigDeadline, sig));
        require(!seenSignatures[key], "signature reused");
        seenSignatures[key] = true;
        
        // Approve the spender to transfer from owner via this contract
        // In real Permit2, this would verify EIP-712 signature
    }
    
    function transferFrom(TransferDetails[] calldata d) external override {
        for (uint256 i; i < d.length; i++) {
            // Transfer tokens using the mock token
            MockERC20(d[i].token).transferFrom(d[i].from, d[i].to, d[i].amount);
        }
    }
    
    function DOMAIN_SEPARATOR() external pure returns (bytes32) {
        return keccak256("mock_permit2");
    }
}

/// @title Tests for depositWithPermit2 functionality
contract DepositWithPermit2Test is Test {
    MockERC20 usdt;
    rkUSDT rk;
    MockPermit2 permit2;
    MockBridgeAdapter adapter;
    ReKaUSDVault vault;
    
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address feeRecipient = address(0xFEE);
    
    function setUp() public {
        // Deploy mocks
        usdt = new MockERC20();
        adapter = new MockBridgeAdapter();
        permit2 = new MockPermit2(address(usdt));
        
        // Deploy rkUSDT
        rk = new rkUSDT();
        
        // Deploy vault with Permit2
        vault = new ReKaUSDVault(
            address(usdt),
            address(rk),
            address(adapter),
            feeRecipient,
            address(permit2),
            7 days
        );
        
        // Set vault address on rkUSDT to allow minting/burning
        rk.setVault(address(vault));
        
        // Setup test users
        usdt.mint(alice, 1_000_000e6);
        usdt.mint(bob, 1_000_000e6);
        
        // Users approve Permit2 (simulating the standard Permit2 flow)
        vm.prank(alice);
        usdt.approve(address(permit2), type(uint256).max);
        vm.prank(bob);
        usdt.approve(address(permit2), type(uint256).max);
    }
    
    function test_depositWithPermit2_happy() public {
        vm.startPrank(alice);
        
        uint256 depositAmount = 100e6; // 100 USDT
        uint256 sigDeadline = block.timestamp + 600;
        bytes memory sig = hex"11"; // Mock signature
        
        // Call depositWithPermit2
        vault.depositWithPermit2(
            alice,
            address(usdt),
            depositAmount,
            sigDeadline,
            sig
        );
        
        // Verify balances
        assertEq(usdt.balanceOf(address(vault)), depositAmount, "Vault should have USDT");
        assertEq(rk.balanceOf(alice), depositAmount, "Alice should have rkUSDT");
        assertEq(vault.currentEpochDeposits(alice), depositAmount, "Epoch deposits should be tracked");
        
        vm.stopPrank();
    }
    
    function test_depositWithPermit2_wrongToken_reverts() public {
        address wrongToken = address(0xDEAD);
        
        vm.expectRevert(ReKaUSDVault.InvalidToken.selector);
        vault.depositWithPermit2(
            alice,
            wrongToken,
            100e6,
            block.timestamp + 600,
            hex"11"
        );
    }
    
    function test_depositWithPermit2_zeroAmount_reverts() public {
        vm.expectRevert(ReKaUSDVault.ZeroAmount.selector);
        vault.depositWithPermit2(
            alice,
            address(usdt),
            0,
            block.timestamp + 600,
            hex"11"
        );
    }
    
    function test_depositWithPermit2_signatureReuse_reverts() public {
        vm.startPrank(alice);
        
        bytes memory sig = hex"BEEF";
        uint256 sigDeadline = block.timestamp + 600;
        
        // First deposit succeeds
        vault.depositWithPermit2(
            alice,
            address(usdt),
            1e6,
            sigDeadline,
            sig
        );
        
        // Second deposit with same signature should fail
        vm.expectRevert("signature reused");
        vault.depositWithPermit2(
            alice,
            address(usdt),
            1e6,
            sigDeadline,
            sig
        );
        
        vm.stopPrank();
    }
    
    function test_depositWithPermit2_multipleUsers() public {
        // Alice deposits
        vm.prank(alice);
        vault.depositWithPermit2(
            alice,
            address(usdt),
            50e6,
            block.timestamp + 600,
            hex"AA"
        );
        
        // Bob deposits
        vm.prank(bob);
        vault.depositWithPermit2(
            bob,
            address(usdt),
            75e6,
            block.timestamp + 600,
            hex"BB"
        );
        
        // Verify balances
        assertEq(rk.balanceOf(alice), 50e6, "Alice should have 50 rkUSDT");
        assertEq(rk.balanceOf(bob), 75e6, "Bob should have 75 rkUSDT");
        assertEq(usdt.balanceOf(address(vault)), 125e6, "Vault should have 125 USDT");
    }
    
    function test_depositWithPermit2_noPermit2_reverts() public {
        // Deploy vault without Permit2
        ReKaUSDVault vaultNoPermit2 = new ReKaUSDVault(
            address(usdt),
            address(rk),
            address(adapter),
            feeRecipient,
            address(0), // No Permit2
            7 days
        );
        
        vm.expectRevert(ReKaUSDVault.Permit2NotSet.selector);
        vaultNoPermit2.depositWithPermit2(
            alice,
            address(usdt),
            100e6,
            block.timestamp + 600,
            hex"11"
        );
    }
    
    function test_depositWithPermit2_epochTracking() public {
        vm.startPrank(alice);
        
        // First deposit
        vault.depositWithPermit2(
            alice,
            address(usdt),
            100e6,
            block.timestamp + 600,
            hex"11"
        );
        
        assertEq(vault.depositEpochOfUser(alice), 0, "Should be epoch 0");
        assertEq(vault.currentEpochDeposits(alice), 100e6, "Should track 100 USDT");
        
        // Second deposit in same epoch
        vault.depositWithPermit2(
            alice,
            address(usdt),
            50e6,
            block.timestamp + 600,
            hex"22"
        );
        
        assertEq(vault.currentEpochDeposits(alice), 150e6, "Should track 150 USDT total");
        
        vm.stopPrank();
    }
}
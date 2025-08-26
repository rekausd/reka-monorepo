// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Open mint USDT (anyone can mint) — testnet faucet purpose
contract MockUSDTMintableOpen {
    string public name;
    string public symbol;
    uint8 public immutable decimals = 6;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory n, string memory s) {
        name = n;
        symbol = s;
    }
    
    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        totalSupply += amt;
        emit Transfer(address(0), to, amt);
    }
    
    function transfer(address to, uint256 amt) external returns (bool) {
        require(balanceOf[msg.sender] >= amt, "Insufficient balance");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        emit Transfer(msg.sender, to, amt);
        return true;
    }
    
    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
        emit Approval(msg.sender, sp, amt);
        return true;
    }
    
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        require(balanceOf[f] >= a, "Insufficient balance");
        uint256 al = allowance[f][msg.sender];
        require(al >= a, "Insufficient allowance");
        if (al != type(uint256).max) {
            allowance[f][msg.sender] = al - a;
        }
        balanceOf[f] -= a;
        balanceOf[t] += a;
        emit Transfer(f, t, a);
        return true;
    }
}

// rkUSDT: mint is restricted to a single minter (Vault)
contract MockRKUSDTMintable {
    string public name;
    string public symbol;
    uint8 public immutable decimals = 6;
    uint256 public totalSupply;
    address public owner;
    address public minter;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event MinterSet(address indexed newMinter);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyMinter() {
        require(msg.sender == minter, "Not minter");
        _;
    }
    
    constructor(string memory n, string memory s) {
        name = n;
        symbol = s;
        owner = msg.sender;
    }
    
    function setMinter(address m) external onlyOwner {
        minter = m;
        emit MinterSet(m);
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    function mint(address to, uint256 amt) external onlyMinter {
        balanceOf[to] += amt;
        totalSupply += amt;
        emit Transfer(address(0), to, amt);
    }
    
    function burn(address from, uint256 amt) external onlyMinter {
        require(balanceOf[from] >= amt, "Insufficient balance");
        balanceOf[from] -= amt;
        totalSupply -= amt;
        emit Transfer(from, address(0), amt);
    }
    
    function transfer(address to, uint256 amt) external returns (bool) {
        require(balanceOf[msg.sender] >= amt, "Insufficient balance");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        emit Transfer(msg.sender, to, amt);
        return true;
    }
    
    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
        emit Approval(msg.sender, sp, amt);
        return true;
    }
    
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        require(balanceOf[f] >= a, "Insufficient balance");
        uint256 al = allowance[f][msg.sender];
        require(al >= a, "Insufficient allowance");
        if (al != type(uint256).max) {
            allowance[f][msg.sender] = al - a;
        }
        balanceOf[f] -= a;
        balanceOf[t] += a;
        emit Transfer(f, t, a);
        return true;
    }
}
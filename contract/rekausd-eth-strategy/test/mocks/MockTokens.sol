// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "./ozlike/ERC20.sol";

contract MockUSDT is ERC20("Tether USD (mock)","USDT") {
    uint8 private immutable _dec = 6;
    constructor() { _mint(msg.sender, 1_000_000_000e6); }
    function decimals() public view override returns (uint8) { return _dec; }
    function mint(address to, uint256 amt) external { _mint(to, amt); }
}

contract MockUSDe is ERC20("USDe (mock)","USDe") {
    constructor() { _mint(msg.sender, 0); }
    function mint(address to, uint256 amt) external { _mint(to, amt); }
    function burn(address from, uint256 amt) external { _burn(from, amt); }
}

contract MockSUSDe is ERC20("Staked USDe (mock)","sUSDe") {
    constructor() { _mint(msg.sender, 0); }
    function mint(address to, uint256 amt) external { _mint(to, amt); }
    function burn(address from, uint256 amt) external { _burn(from, amt); }
}

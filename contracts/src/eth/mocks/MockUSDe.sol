// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSDe is ERC20, Ownable {
    mapping(address => bool) public isMinter;
    constructor() ERC20("USDe (mock)", "USDe") Ownable(msg.sender) {}

    function setMinter(address minter, bool allowed) external onlyOwner {
        isMinter[minter] = allowed;
    }

    function mint(address to, uint256 amount) external {
        require(isMinter[msg.sender] || msg.sender == owner(), "not minter");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(isMinter[msg.sender] || msg.sender == owner(), "not minter");
        _burn(from, amount);
    }
}

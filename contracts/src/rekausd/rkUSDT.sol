// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title ReKaUSD Restaked USDT (rkUSDT)
/// @notice Receipt token minted 1:1 on deposit into the vault.
contract rkUSDT is ERC20, Ownable2Step {
    address public vault;

    error NotVault();
    error ZeroAddress();

    constructor() ERC20("ReKaUSD Restaked USDT", "rkUSDT") Ownable(msg.sender) {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function setVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert ZeroAddress();
        vault = _vault;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != vault) revert NotVault();
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        if (msg.sender != vault) revert NotVault();
        _burn(from, amount);
    }
}

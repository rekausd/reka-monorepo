// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockUSDe} from "./MockUSDe.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockSwapUSDTtoUSDe is Ownable {
    IERC20 public immutable USDT;
    MockUSDe public immutable USDe;

    uint256 public rateBps; // 10000 = 1:1

    event Swapped(address indexed from, address indexed to, uint256 usdtIn, uint256 usdeOut);

    constructor(address usdt, address usde) Ownable(msg.sender) {
        require(usdt != address(0) && usde != address(0), "zero");
        USDT = IERC20(usdt);
        USDe = MockUSDe(usde);
        rateBps = 10_000;
    }

    function setRateBps(uint256 newRate) external onlyOwner {
        require(newRate > 0, "rate");
        rateBps = newRate;
    }

    function recoverERC20(address token, uint256 amt) external onlyOwner {
        IERC20(token).transfer(owner(), amt);
    }

    function swap(uint256 usdtAmount, address to) external {
        require(usdtAmount > 0, "amt");
        require(to != address(0), "to");
        // pull USDT
        require(USDT.transferFrom(msg.sender, address(this), usdtAmount), "pull");
        // compute USDe out with decimals handling
        uint256 usdeOut = usdtAmount * rateBps / 10_000 * 1e12; // 6d -> 18d
        USDe.mint(to, usdeOut);
        emit Swapped(msg.sender, to, usdtAmount, usdeOut);
    }
}

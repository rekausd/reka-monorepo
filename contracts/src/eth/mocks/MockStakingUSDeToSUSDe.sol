// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockUSDe} from "./MockUSDe.sol";
import {MockSUSDe} from "./MockSUSDe.sol";
import {YieldMath} from "reka-mocks/libs/YieldMath.sol";

contract MockStakingUSDeToSUSDe is Ownable {
    using YieldMath for uint256;

    MockUSDe public immutable USDe;
    MockSUSDe public immutable sUSDe;

    uint256 public accIndexRay; // 1e27
    uint40 public lastUpdate;
    uint256 public rPerSecRay;
    uint256 public baseAssetsRay; // normalized assets such that virtual = base * accIndex / RAY

    event Accrued(uint256 accIndexRay, uint256 timestamp);
    event Staked(address indexed user, uint256 amount, uint256 shares);
    event Unstaked(address indexed user, uint256 shares, uint256 amountOut);
    event Harvest(uint256 mintedYield);

    constructor(address usde, address susde, uint256 apyBps) Ownable(msg.sender) {
        require(usde != address(0) && susde != address(0), "zero");
        USDe = MockUSDe(usde);
        sUSDe = MockSUSDe(susde);
        accIndexRay = YieldMath.RAY();
        lastUpdate = uint40(block.timestamp);
        _setAPYBpsInternal(apyBps);
    }

    function totalShares() public view returns (uint256) {
        return sUSDe.totalSupply();
    }

    function virtualAssets() public view returns (uint256) {
        uint256 dt = block.timestamp - lastUpdate;
        uint256 idx = accIndexRay * (YieldMath.RAY() + rPerSecRay).powRay(dt) / YieldMath.RAY();
        return baseAssetsRay.mulDivRay(idx);
    }

    function previewStake(uint256 usdeAmount) external view returns (uint256) {
        uint256 ts = totalShares();
        if (ts == 0) return usdeAmount;
        uint256 vAssets = virtualAssets();
        return usdeAmount * ts / vAssets;
    }

    function previewUnstake(uint256 shares) external view returns (uint256) {
        uint256 ts = totalShares();
        uint256 vAssets = virtualAssets();
        if (ts == 0) return 0;
        return shares * vAssets / ts;
    }

    function setAPYBps(uint256 apyBps) external onlyOwner {
        _setAPYBpsInternal(apyBps);
    }

    function _setAPYBpsInternal(uint256 apyBps) internal {
        // choose rPerSecRay such that (RAY + r)^YEAR ~= RAY * (1 + apy)
        uint256 target = YieldMath.RAY() * (10_000 + apyBps) / 10_000; // ray
        uint256 lo = 0;
        uint256 hi = target - YieldMath.RAY(); // safe upper bound
        uint256 mid;
        for (uint256 i = 0; i < 64; i++) {
            mid = (lo + hi) / 2;
            uint256 f = (YieldMath.RAY() + mid).powRay(365 days);
            if (f < target) {
                lo = mid;
            } else {
                hi = mid;
            }
        }
        rPerSecRay = lo;
    }

    function _accrue() internal {
        uint256 dt = block.timestamp - lastUpdate;
        if (dt == 0) return;
        uint256 growth = (YieldMath.RAY() + rPerSecRay).powRay(dt);
        accIndexRay = accIndexRay.mulDivRay(growth);
        lastUpdate = uint40(block.timestamp);
        emit Accrued(accIndexRay, block.timestamp);
    }

    function stake(uint256 amount, address to) external {
        require(amount > 0, "amt");
        _accrue();
        uint256 ts = totalShares();
        uint256 vAssets = _virtualAssetsWithAccIndex();
        require(USDe.transferFrom(msg.sender, address(this), amount), "pull");
        uint256 shares = ts == 0 ? amount : amount * ts / vAssets;
        sUSDe.mint(to, shares);
        // normalize deposit into base units
        baseAssetsRay += amount * YieldMath.RAY() / accIndexRay;
        emit Staked(msg.sender, amount, shares);
    }

    function unstake(uint256 shares, address to) external {
        require(shares > 0, "shares");
        _accrue();
        uint256 ts = totalShares();
        uint256 vAssets = _virtualAssetsWithAccIndex();
        uint256 amountOut = shares * vAssets / ts;
        sUSDe.burn(msg.sender, shares);
        // reduce base assets accordingly
        baseAssetsRay -= amountOut * YieldMath.RAY() / accIndexRay;
        _materializeYield();
        // ensure sufficient on-chain balance to transfer
        uint256 bal = USDe.balanceOf(address(this));
        if (bal < amountOut) {
            USDe.mint(address(this), amountOut - bal);
        }
        require(USDe.transfer(to, amountOut), "xfer");
        emit Unstaked(msg.sender, shares, amountOut);
    }

    function harvest() external {
        _accrue();
        uint256 beforeBal = USDe.balanceOf(address(this));
        _materializeYield();
        uint256 afterBal = USDe.balanceOf(address(this));
        emit Harvest(afterBal - beforeBal);
    }

    function _materializeYield() internal {
        uint256 virt = _virtualAssetsWithAccIndex();
        uint256 bal = USDe.balanceOf(address(this));
        if (virt > bal) {
            USDe.mint(address(this), virt - bal);
        }
    }

    function _virtualAssetsWithAccIndex() internal view returns (uint256) {
        return baseAssetsRay.mulDivRay(accIndexRay);
    }
}

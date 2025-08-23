// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapAdapter} from "reka-common/adapters/ISwapAdapter.sol";
import {SafeERC20Compat} from "reka-common/utils/SafeERC20Compat.sol";

interface ICurvePool {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external payable returns (uint256);
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
}

interface IUniswapV3Router {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata p) external payable returns (uint256);
}

interface IUniswapV3Quoter {
    function quoteExactInputSingle(address tokenIn,address tokenOut,uint24 fee,uint256 amountIn,uint160 sqrtPriceLimitX96) external view returns (uint256);
}

contract MetaSwapAdapter is ISwapAdapter {
    using SafeERC20Compat for IERC20;

    IERC20 public immutable USDT;
    IERC20 public immutable USDe;

    // Curve
    ICurvePool public immutable curvePool;
    int128 public immutable curveUsdtIndex;
    int128 public immutable curveUsdeIndex;

    // UniV3
    IUniswapV3Router public immutable uniRouter;
    IUniswapV3Quoter public immutable uniQuoter;
    uint24 public immutable uniFee;

    address public immutable owner;

    error MinOutTooHigh();

    constructor(
        address _usdt,
        address _usde,
        address _curvePool,
        int128 _curveUsdtIndex,
        int128 _curveUsdeIndex,
        address _uniRouter,
        address _uniQuoter,
        uint24 _uniFee
    ) {
        require(_usdt != address(0) && _usde != address(0), "ZERO_TOKEN");
        require(_curvePool != address(0) || (_uniRouter != address(0) && _uniQuoter != address(0)), "NO_ROUTE");

        USDT = IERC20(_usdt);
        USDe = IERC20(_usde);

        curvePool = ICurvePool(_curvePool);
        curveUsdtIndex = _curveUsdtIndex;
        curveUsdeIndex = _curveUsdeIndex;

        uniRouter = IUniswapV3Router(_uniRouter);
        uniQuoter = IUniswapV3Quoter(_uniQuoter);
        uniFee = _uniFee;

        owner = msg.sender;

        if (_uniRouter != address(0)) {
            USDT.safeApprove(_uniRouter, type(uint256).max);
            USDe.safeApprove(_uniRouter, type(uint256).max);
        }
    }

    // ---- Quotes ----
    function quoteUSDTtoUSDe(uint256 usdtIn) public view returns (uint256 best) {
        // Curve
        if (address(curvePool) != address(0)) {
            try curvePool.get_dy(curveUsdtIndex, curveUsdeIndex, usdtIn) returns (uint256 dy) { if (dy > best) best = dy; } catch {}
        }
        // UniV3
        if (address(uniQuoter) != address(0)) {
            try uniQuoter.quoteExactInputSingle(address(USDT), address(USDe), uniFee, usdtIn, 0) returns (uint256 out) { if (out > best) best = out; } catch {}
        }
    }

    function quoteUSDetoUSDT(uint256 usdeIn) public view returns (uint256 best) {
        if (address(curvePool) != address(0)) {
            try curvePool.get_dy(curveUsdeIndex, curveUsdtIndex, usdeIn) returns (uint256 dy) { if (dy > best) best = dy; } catch {}
        }
        if (address(uniQuoter) != address(0)) {
            try uniQuoter.quoteExactInputSingle(address(USDe), address(USDT), uniFee, usdeIn, 0) returns (uint256 out) { if (out > best) best = out; } catch {}
        }
    }

    // ---- Swaps ----
    function swapExactUSDTForUSDe(uint256 usdtIn, uint256 minUsdeOut, address to) external returns (uint256 amountOut) {
        // Pull in
        USDT.safeTransferFrom(msg.sender, address(this), usdtIn);

        uint256 qCurve = 0; uint256 qUni = 0;
        if (address(curvePool) != address(0)) { try curvePool.get_dy(curveUsdtIndex, curveUsdeIndex, usdtIn) returns (uint256 dy) { qCurve = dy; } catch {} }
        if (address(uniQuoter) != address(0)) { try uniQuoter.quoteExactInputSingle(address(USDT), address(USDe), uniFee, usdtIn, 0) returns (uint256 out) { qUni = out; } catch {} }

        if (qCurve >= qUni && qCurve > 0 && address(curvePool) != address(0)) {
            amountOut = curvePool.exchange(curveUsdtIndex, curveUsdeIndex, usdtIn, minUsdeOut);
            USDe.safeTransfer(to, amountOut);
        } else if (qUni > 0 && address(uniRouter) != address(0)) {
            IUniswapV3Router.ExactInputSingleParams memory p = IUniswapV3Router.ExactInputSingleParams({
                tokenIn: address(USDT),
                tokenOut: address(USDe),
                fee: uniFee,
                recipient: to,
                deadline: block.timestamp,
                amountIn: usdtIn,
                amountOutMinimum: minUsdeOut,
                sqrtPriceLimitX96: 0
            });
            amountOut = IUniswapV3Router(uniRouter).exactInputSingle(p);
        } else {
            revert MinOutTooHigh();
        }
        require(amountOut >= minUsdeOut, "MIN_OUT");
    }

    function swapExactUSDeForUSDT(uint256 usdeIn, uint256 minUsdtOut, address to) external returns (uint256 amountOut) {
        USDe.safeTransferFrom(msg.sender, address(this), usdeIn);

        uint256 qCurve = 0; uint256 qUni = 0;
        if (address(curvePool) != address(0)) { try curvePool.get_dy(curveUsdeIndex, curveUsdtIndex, usdeIn) returns (uint256 dy) { qCurve = dy; } catch {} }
        if (address(uniQuoter) != address(0)) { try uniQuoter.quoteExactInputSingle(address(USDe), address(USDT), uniFee, usdeIn, 0) returns (uint256 out) { qUni = out; } catch {} }

        if (qCurve >= qUni && qCurve > 0 && address(curvePool) != address(0)) {
            amountOut = curvePool.exchange(curveUsdeIndex, curveUsdtIndex, usdeIn, minUsdtOut);
            IERC20(USDT).transfer(to, amountOut);
        } else if (qUni > 0 && address(uniRouter) != address(0)) {
            IUniswapV3Router.ExactInputSingleParams memory p = IUniswapV3Router.ExactInputSingleParams({
                tokenIn: address(USDe),
                tokenOut: address(USDT),
                fee: uniFee,
                recipient: to,
                deadline: block.timestamp,
                amountIn: usdeIn,
                amountOutMinimum: minUsdtOut,
                sqrtPriceLimitX96: 0
            });
            amountOut = IUniswapV3Router(uniRouter).exactInputSingle(p);
        } else {
            revert MinOutTooHigh();
        }
        require(amountOut >= minUsdtOut, "MIN_OUT");
    }

    // optional rescue
    function rescue(IERC20 token, address to, uint256 amt) external {
        require(msg.sender == owner, "NOT_OWNER");
        token.safeTransfer(to, amt);
    }
}

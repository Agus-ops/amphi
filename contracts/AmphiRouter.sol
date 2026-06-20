// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Interfaces.sol";

contract AmphiRouter {
    event LiquidityAdded(address indexed provider, address indexed pair, uint256 a, uint256 b, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, address indexed pair, uint256 a, uint256 b, uint256 liquidity);
    event Swapped(address indexed user, address indexed pair, uint256 amountIn, uint256 amountOut, address tokenIn, address tokenOut);

    address public immutable factory;

    modifier ensure(uint256 deadline) { require(block.timestamp <= deadline, "EXPIRED"); _; }

    constructor(address _factory) { factory = _factory; }

    function addLiquidity(address a, address b, uint256 aDes, uint256 bDes,
        uint256 aMin, uint256 bMin, address to, uint256 deadline)
        external ensure(deadline) returns (uint256 aAmt, uint256 bAmt, uint256 liq)
    {
        (address pair, uint256 r0, uint256 r1) = _pair(a, b);
        if (r0 == 0 && r1 == 0) { aAmt = aDes; bAmt = bDes; }
        else {
            uint256 bOpt = aDes * r1 / r0;
            if (bOpt <= bDes) {
                require(bOpt >= bMin, "B_LOW");
                aAmt = aDes; bAmt = bOpt;
            } else {
                uint256 aOpt = bDes * r0 / r1;
                require(aOpt >= aMin, "A_LOW");
                aAmt = aOpt; bAmt = bDes;
            }
        }
        _safeTransferFrom(a, msg.sender, pair, aAmt);
        _safeTransferFrom(b, msg.sender, pair, bAmt);
        liq = IAmphiPair(pair).mint(to);
        emit LiquidityAdded(msg.sender, pair, aAmt, bAmt, liq);
    }

    function removeLiquidity(address a, address b, uint256 liq, uint256 aMin, uint256 bMin, address to, uint256 deadline)
        external ensure(deadline) returns (uint256 aAmt, uint256 bAmt)
    {
        address pair = IAmphiFactory(factory).getPair(a, b);
        require(pair != address(0), "PAIR_NOT_FOUND");
        IAmphiPair(pair).transferFrom(msg.sender, pair, liq);
        (uint256 amount0, uint256 amount1) = IAmphiPair(pair).burn(to);
        (aAmt, bAmt) = a < b ? (amount0, amount1) : (amount1, amount0);
        require(aAmt >= aMin && bAmt >= bMin, "SLIPPAGE");
        emit LiquidityRemoved(msg.sender, pair, aAmt, bAmt, liq);
    }

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address tokenIn, address tokenOut, address to, uint256 deadline)
        external ensure(deadline) returns (uint256 amountOut)
    {
        address pair = IAmphiFactory(factory).getPair(tokenIn, tokenOut);
        require(pair != address(0), "PAIR_NOT_FOUND");
        (uint256 r0, uint256 r1, ) = IAmphiPair(pair).getReserves();
        uint256 reserveIn; uint256 reserveOut;
        if (tokenIn < tokenOut) { reserveIn = r0; reserveOut = r1; }
        else { reserveIn = r1; reserveOut = r0; }
        require(reserveIn > 0 && reserveOut > 0, "NO_LIQ");

        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
        require(amountOut >= amountOutMin, "SLIPPAGE");

        _safeTransferFrom(tokenIn, msg.sender, pair, amountIn);
        if (tokenIn < tokenOut) IAmphiPair(pair).swap(0, amountOut, to);
        else IAmphiPair(pair).swap(amountOut, 0, to);
        emit Swapped(msg.sender, pair, amountIn, amountOut, tokenIn, tokenOut);
    }

    function getAmountOut(uint256 amountIn, address tokenIn, address tokenOut) external view returns (uint256) {
        address pair = IAmphiFactory(factory).getPair(tokenIn, tokenOut);
        require(pair != address(0), "PAIR_NOT_FOUND");
        (uint256 r0, uint256 r1, ) = IAmphiPair(pair).getReserves();
        (uint256 reserveIn, uint256 reserveOut) = tokenIn < tokenOut ? (r0, r1) : (r1, r0);
        uint256 amountInWithFee = amountIn * 997;
        return (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }

    function _pair(address a, address b) internal view returns (address p, uint256 r0, uint256 r1) {
        p = IAmphiFactory(factory).getPair(a, b);
        require(p != address(0), "PAIR_NOT_FOUND");
        (uint256 x, uint256 y, ) = IAmphiPair(p).getReserves();
        if (a < b) { r0 = x; r1 = y; }
        else { r0 = y; r1 = x; }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool ok, ) = token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, value));
        require(ok, "TRANSFER_FROM_FAIL");
    }
}

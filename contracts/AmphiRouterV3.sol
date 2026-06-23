// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAmphiPair {
    function transferFrom(address, address, uint256) external returns (bool);
    function mint(address) external returns (uint256);
    function burn(address) external returns (uint256, uint256);
    function swap(uint256, uint256, address) external;
    function getReserves() external view returns (uint112, uint112, uint32);
}

interface IAmphiFactory {
    function getPair(address, address) external view returns (address);
}

contract AmphiRouterV3 {
    event LiquidityAdded(address indexed provider, address indexed pair, uint256 a, uint256 b, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, address indexed pair, uint256 a, uint256 b, uint256 liquidity);
    event Swapped(address indexed user, address[] path, uint256 amountIn, uint256 amountOut);

    address public immutable factory;
    uint256 private _locked = 1;

    modifier ensure(uint256 deadline) {
        require(block.timestamp <= deadline, "EXPIRED");
        _;
    }

    modifier nonReentrant() {
        require(_locked == 1, "REENTRANCY");
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address _factory) {
        require(_factory != address(0), "ZERO_FACTORY");
        factory = _factory;
    }

    // ============ LIQUIDITY ============
    function addLiquidity(
        address a, address b, uint256 aDes, uint256 bDes,
        uint256 aMin, uint256 bMin, address to, uint256 deadline
    ) external nonReentrant ensure(deadline) returns (uint256 aAmt, uint256 bAmt, uint256 liq) {
        (address pair, uint256 r0, uint256 r1) = _pair(a, b);
        if (r0 == 0 && r1 == 0) {
            require(aDes >= aMin && bDes >= bMin, "SLIPPAGE");
            aAmt = aDes;
            bAmt = bDes;
        }
        else {
            require(r0 > 0 && r1 > 0, "BAD_RESERVES");
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

    function removeLiquidity(
        address a, address b, uint256 liq, uint256 aMin, uint256 bMin, address to, uint256 deadline
    ) external nonReentrant ensure(deadline) returns (uint256 aAmt, uint256 bAmt) {
        address pair = IAmphiFactory(factory).getPair(a, b);
        require(pair != address(0), "PAIR_NOT_FOUND");
        IAmphiPair(pair).transferFrom(msg.sender, pair, liq);
        (uint256 amount0, uint256 amount1) = IAmphiPair(pair).burn(to);
        (aAmt, bAmt) = a < b ? (amount0, amount1) : (amount1, amount0);
        require(aAmt >= aMin && bAmt >= bMin, "SLIPPAGE");
        emit LiquidityRemoved(msg.sender, pair, aAmt, bAmt, liq);
    }

    // ============ SWAP MULTIHOP ============
    function swapExactTokensForTokens(
        uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline
    ) external nonReentrant ensure(deadline) returns (uint256 amountOut) {
        require(path.length >= 2, "INVALID_PATH");

        address pair = _getPair(path[0], path[1]);
        _safeTransferFrom(path[0], msg.sender, pair, amountIn);

        amountOut = amountIn;
        for (uint256 i = 0; i < path.length - 1; i++) {
            address input = path[i];
            address output = path[i + 1];
            {
                (uint256 reserveIn, uint256 reserveOut) = _getReserves(input, output, pair);
                amountOut = _getAmountOut(amountOut, reserveIn, reserveOut);
            }
            address recipient;
            address currentPair = pair;
            if (i == path.length - 2) recipient = to;
            else {
                pair = _getPair(output, path[i + 2]);
                recipient = pair;
            }
            if (input < output) IAmphiPair(currentPair).swap(0, amountOut, recipient);
            else IAmphiPair(currentPair).swap(amountOut, 0, recipient);
        }
        require(amountOut >= amountOutMin, "SLIPPAGE");
        emit Swapped(msg.sender, path, amountIn, amountOut);
    }

    // ============ QUOTE (untuk UI) ============
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts) {
        require(path.length >= 2, "INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i = 0; i < path.length - 1; i++) {
            address pair = _getPair(path[i], path[i + 1]);
            (uint256 reserveIn, uint256 reserveOut) = _getReserves(path[i], path[i + 1], pair);
            amounts[i + 1] = _getAmountOut(amounts[i], reserveIn, reserveOut);
        }
        return amounts;
    }

    // ============ HELPERS ============
    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_AMOUNT");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }

    function _getReserves(address tokenA, address tokenB, address pair) internal view returns (uint256 rA, uint256 rB) {
        (uint112 r0, uint112 r1,) = IAmphiPair(pair).getReserves();
        (rA, rB) = tokenA < tokenB ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
    }

    function _getPair(address tokenA, address tokenB) internal view returns (address pair) {
        pair = IAmphiFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "PAIR_NOT_FOUND");
    }

    function _pair(address a, address b) internal view returns (address p, uint256 r0, uint256 r1) {
        p = IAmphiFactory(factory).getPair(a, b);
        require(p != address(0), "PAIR_NOT_FOUND");
        (uint256 x, uint256 y,) = IAmphiPair(p).getReserves();
        if (a < b) { r0 = x; r1 = y; } else { r0 = y; r1 = x; }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FROM_FAIL");
    }
}

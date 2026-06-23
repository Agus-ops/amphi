// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IShared.sol";

contract PoolSeederV2 {
    error ZeroAddress();
    error StaleOracle();
    error ZeroPrice();
    error SetupFailed();
    error ApprovalFailed();
    error LiquidityAddFailed();

    event LiquidityAdded(address indexed pair, uint256 amount0, uint256 amount1);
    event OwnershipReturned(address indexed token, address newOwner);
    event AllComplete();

    address public immutable oracle;
    address public immutable router;
    address public immutable multisig;

    address public immutable mUSDC;
    address public immutable mBTC;
    address public immutable mETH;
    address public immutable mSOL;
    address public immutable mGold;
    address public immutable mSilver;
    address public immutable mPlatinum;

    uint256 public constant TARGET_USD_PER_SIDE = 200_000;
    uint256 private constant PRICE_DECIMALS = 1e8;
    uint256 private constant TOKEN_DECIMALS = 1e18;

    constructor(
        address _oracle, address _router, address _multisig,
        address _mUSDC, address _mBTC, address _mETH, address _mSOL,
        address _mGold, address _mSilver, address _mPlatinum
    ) {
        oracle = _oracle; router = _router; multisig = _multisig;
        mUSDC = _mUSDC; mBTC = _mBTC; mETH = _mETH; mSOL = _mSOL;
        mGold = _mGold; mSilver = _mSilver; mPlatinum = _mPlatinum;
    }

    function seedAll(
        address pairUSDC_BTC, address pairUSDC_ETH, address pairUSDC_SOL,
        address pairUSDC_Gold, address pairUSDC_Silver, address pairUSDC_Platinum
    ) external {
        IOracle oracleContract = IOracle(oracle);
        if (oracleContract.isStale()) revert StaleOracle();

        uint256 ethPrice = oracleContract.getEthUsd();
        uint256 btcPrice = oracleContract.getBtcUsd();
        uint256 solPrice = oracleContract.getSolUsd();
        uint256 goldPrice = oracleContract.getGoldPricePerGram();
        uint256 silverPrice = oracleContract.getSilverPricePerGram();
        uint256 platinumPrice = oracleContract.getPlatinumPricePerGram();

        if (ethPrice == 0 || btcPrice == 0 || solPrice == 0 ||
            goldPrice == 0 || silverPrice == 0 || platinumPrice == 0) revert ZeroPrice();

        uint256 usdcAmount = TARGET_USD_PER_SIDE * TOKEN_DECIMALS;
        uint256 btcAmount  = (TARGET_USD_PER_SIDE * TOKEN_DECIMALS * PRICE_DECIMALS) / btcPrice;
        uint256 ethAmount  = (TARGET_USD_PER_SIDE * TOKEN_DECIMALS * PRICE_DECIMALS) / ethPrice;
        uint256 solAmount  = (TARGET_USD_PER_SIDE * TOKEN_DECIMALS * PRICE_DECIMALS) / solPrice;
        uint256 goldAmount = (TARGET_USD_PER_SIDE * TOKEN_DECIMALS * TOKEN_DECIMALS) / goldPrice;
        uint256 silverAmount = (TARGET_USD_PER_SIDE * TOKEN_DECIMALS * TOKEN_DECIMALS) / silverPrice;
        uint256 platinumAmount = (TARGET_USD_PER_SIDE * TOKEN_DECIMALS * TOKEN_DECIMALS) / platinumPrice;

        uint256 totalUSDC = usdcAmount * 6;

        _ownerMint(mUSDC, totalUSDC);
        _ownerMint(mBTC, btcAmount);
        _ownerMint(mETH, ethAmount);
        _ownerMint(mSOL, solAmount);
        _ownerMint(mGold, goldAmount);
        _ownerMint(mSilver, silverAmount);
        _ownerMint(mPlatinum, platinumAmount);

        _approve(mUSDC, router, totalUSDC);
        _approve(mBTC, router, btcAmount);
        _approve(mETH, router, ethAmount);
        _approve(mSOL, router, solAmount);
        _approve(mGold, router, goldAmount);
        _approve(mSilver, router, silverAmount);
        _approve(mPlatinum, router, platinumAmount);

        uint256 deadline = block.timestamp + 1200;

        _addLiquidityViaRouter(mUSDC, mBTC, usdcAmount, btcAmount, deadline);
        _addLiquidityViaRouter(mUSDC, mETH, usdcAmount, ethAmount, deadline);
        _addLiquidityViaRouter(mUSDC, mSOL, usdcAmount, solAmount, deadline);
        _addLiquidityViaRouter(mUSDC, mGold, usdcAmount, goldAmount, deadline);
        _addLiquidityViaRouter(mUSDC, mSilver, usdcAmount, silverAmount, deadline);
        _addLiquidityViaRouter(mUSDC, mPlatinum, usdcAmount, platinumAmount, deadline);

        _finalizeSeeding(mUSDC);
        _finalizeSeeding(mBTC);
        _finalizeSeeding(mETH);
        _finalizeSeeding(mSOL);
        _finalizeSeeding(mGold);
        _finalizeSeeding(mSilver);
        _finalizeSeeding(mPlatinum);

        _returnOwnership(mUSDC);
        _returnOwnership(mBTC);
        _returnOwnership(mETH);
        _returnOwnership(mSOL);
        _returnOwnership(mGold);
        _returnOwnership(mSilver);
        _returnOwnership(mPlatinum);

        emit AllComplete();
    }

    function _ownerMint(address token, uint256 amount) internal {
        (bool ok,) = token.call(abi.encodeWithSignature("ownerMint(address,uint256)", address(this), amount));
        if (!ok) revert SetupFailed();
    }

    function _approve(address token, address spender, uint256 amount) internal {
        (bool ok,) = token.call(abi.encodeWithSignature("approve(address,uint256)", spender, amount));
        if (!ok) revert ApprovalFailed();
    }

    function _addLiquidityViaRouter(address tokenA, address tokenB, uint256 amtA, uint256 amtB, uint256 deadline) internal {
        (bool ok,) = router.call(
            abi.encodeWithSignature(
                "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)",
                tokenA, tokenB, amtA, amtB, 0, 0, multisig, deadline
            )
        );
        if (!ok) revert LiquidityAddFailed();
    }

    function _finalizeSeeding(address token) internal {
        (bool ok,) = token.call(abi.encodeWithSignature("finalizeSeeding()"));
        if (!ok) revert SetupFailed();
    }

    function _returnOwnership(address token) internal {
        (bool ok,) = token.call(abi.encodeWithSignature("setOwner(address)", multisig));
        if (!ok) revert SetupFailed();
        emit OwnershipReturned(token, multisig);
    }
}

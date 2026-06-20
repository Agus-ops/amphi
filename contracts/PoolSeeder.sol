// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Interfaces.sol";

contract PoolSeeder {
    address public immutable oracle;
    address public immutable router;
    address public immutable multisig;

    address public immutable mUSDC;
    address public immutable mBTC;
    address public immutable mETH;
    address public immutable mGold;
    address public immutable goldVault;

    uint256 public constant TARGET_USD_PER_SIDE = 10000;
    uint256 private constant PRICE_DECIMALS = 1e8;
    uint256 private constant TOKEN_DECIMALS = 1e18;
    uint256 private constant BOOTSTRAP_LOCK_AMOUNT = 1 * 1e18;
    uint256 private constant BOOTSTRAP_LOCK_DURATION = 7 days;

    event PoolSeeded(address indexed pair, uint256 amount0, uint256 amount1);
    event OwnershipReturned(address indexed token, address newOwner);
    event BootstrapLocker(address indexed vault, uint256 amount);

    constructor(
        address _oracle,
        address _router,
        address _multisig,
        address _mUSDC,
        address _mBTC,
        address _mETH,
        address _mGold,
        address _goldVault
    ) {
        oracle = _oracle;
        router = _router;
        multisig = _multisig;
        mUSDC = _mUSDC;
        mBTC = _mBTC;
        mETH = _mETH;
        mGold = _mGold;
        goldVault = _goldVault;
    }

    function seedAll() external {
        IOracle oracleContract = IOracle(oracle);
        require(block.timestamp - oracleContract.lastUpdate() <= oracleContract.STALENESS_THRESHOLD(), "STALE_ORACLE");

        uint256 ethPrice = oracleContract.ethUsd();
        uint256 btcPrice = oracleContract.btcUsd();
        uint256 goldPrice = oracleContract.getGoldPricePerGram();
        require(ethPrice > 0 && btcPrice > 0 && goldPrice > 0, "ZERO_PRICE");

        uint256 usdcAmount = TARGET_USD_PER_SIDE * TOKEN_DECIMALS;
        uint256 btcAmount  = (TARGET_USD_PER_SIDE * TOKEN_DECIMALS * PRICE_DECIMALS) / btcPrice;
        uint256 ethAmount  = (TARGET_USD_PER_SIDE * TOKEN_DECIMALS * PRICE_DECIMALS) / ethPrice;
        uint256 goldAmount = (TARGET_USD_PER_SIDE * TOKEN_DECIMALS * TOKEN_DECIMALS) / goldPrice;

        IMintableToken(mUSDC).ownerMint(address(this), usdcAmount * 3);
        IMintableToken(mBTC).ownerMint(address(this), btcAmount);
        IMintableToken(mETH).ownerMint(address(this), ethAmount);
        IMintableToken(mGold).ownerMint(address(this), goldAmount + BOOTSTRAP_LOCK_AMOUNT);

        _approve(mUSDC, router, usdcAmount * 3);
        _approve(mBTC, router, btcAmount);
        _approve(mETH, router, ethAmount);
        _approve(mGold, router, goldAmount);

        uint256 deadline = block.timestamp + 600;
        _addLiquidity(mUSDC, mBTC, usdcAmount, btcAmount, deadline);
        _addLiquidity(mUSDC, mETH, usdcAmount, ethAmount, deadline);
        _addLiquidity(mUSDC, mGold, usdcAmount, goldAmount, deadline);

        _approve(mGold, goldVault, BOOTSTRAP_LOCK_AMOUNT);
        IGoldVault(goldVault).lock(BOOTSTRAP_LOCK_AMOUNT, BOOTSTRAP_LOCK_DURATION);
        emit BootstrapLocker(goldVault, BOOTSTRAP_LOCK_AMOUNT);

        IMintableToken(mUSDC).finalizeSeeding();
        IMintableToken(mBTC).finalizeSeeding();
        IMintableToken(mETH).finalizeSeeding();
        IMintableToken(mGold).finalizeSeeding();

        IMintableToken(mUSDC).setOwner(multisig);
        IMintableToken(mBTC).setOwner(multisig);
        IMintableToken(mETH).setOwner(multisig);
        IMintableToken(mGold).setOwner(multisig);
        emit OwnershipReturned(mUSDC, multisig);
        emit OwnershipReturned(mBTC, multisig);
        emit OwnershipReturned(mETH, multisig);
        emit OwnershipReturned(mGold, multisig);
    }

    function _approve(address token, address spender, uint256 amount) internal {
        (bool ok, ) = token.call(abi.encodeWithSignature("approve(address,uint256)", spender, amount));
        require(ok, "APPROVE_FAILED");
    }

    function _addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB, uint256 deadline) internal {
        (bool ok, ) = router.call(
            abi.encodeWithSignature(
                "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)",
                tokenA, tokenB, amountA, amountB, 0, 0, multisig, deadline
            )
        );
        require(ok, "ADD_LIQUIDITY_FAILED");
    }
}

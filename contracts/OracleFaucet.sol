// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Interfaces.sol";

contract OracleFaucet {
    event Claimed(address indexed user, uint256 usdc, uint256 btc, uint256 eth, uint256 gold);

    mapping(address => bool) public claimed;

    IERC20Mintable public immutable usdc;
    IERC20Mintable public immutable btc;
    IERC20Mintable public immutable eth;
    IERC20Mintable public immutable gold;
    IOracleFull public immutable oracle;

    uint256 public constant TARGET_USD = 500;
    uint256 private constant PRICE_DECIMALS = 1e8;
    uint256 private constant TOKEN_DECIMALS = 1e18;

    constructor(address _usdc, address _btc, address _eth, address _gold, address _oracle) {
        usdc = IERC20Mintable(_usdc);
        btc  = IERC20Mintable(_btc);
        eth  = IERC20Mintable(_eth);
        gold = IERC20Mintable(_gold);
        oracle = IOracleFull(_oracle);
    }

    function claim() external {
        require(!claimed[msg.sender], "ALREADY_CLAIMED");
        claimed[msg.sender] = true;

        uint256 last = oracle.lastUpdate();
        require(block.timestamp - last <= oracle.STALENESS_THRESHOLD(), "STALE_ORACLE");

        uint256 ethPrice = oracle.ethUsd();
        uint256 btcPrice = oracle.btcUsd();
        uint256 goldPrice = oracle.getGoldPricePerGram();
        require(ethPrice > 0 && btcPrice > 0 && goldPrice > 0, "ZERO_PRICE");

        uint256 amountUSDC = TARGET_USD * TOKEN_DECIMALS;
        uint256 amountBTC  = (TARGET_USD * TOKEN_DECIMALS * PRICE_DECIMALS) / btcPrice;
        uint256 amountETH  = (TARGET_USD * TOKEN_DECIMALS * PRICE_DECIMALS) / ethPrice;
        uint256 amountGold = (TARGET_USD * TOKEN_DECIMALS * TOKEN_DECIMALS) / goldPrice;

        usdc.mint(msg.sender, amountUSDC);
        btc.mint(msg.sender, amountBTC);
        eth.mint(msg.sender, amountETH);
        gold.mint(msg.sender, amountGold);

        emit Claimed(msg.sender, amountUSDC, amountBTC, amountETH, amountGold);
    }
}

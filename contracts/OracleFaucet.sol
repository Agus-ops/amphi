// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IShared.sol";

contract OracleFaucet {
    error ZeroAddress();
    error AlreadyClaimed();
    error StaleOracle();
    error ZeroPrice();

    event Claimed(
        address indexed user,
        uint256 usdc, uint256 btc, uint256 eth, uint256 sol,
        uint256 gold, uint256 silver, uint256 platinum
    );

    uint256 public constant TARGET_USD = 500;
    uint256 private constant PRICE_DECIMALS = 1e8;
    uint256 private constant TOKEN_DECIMALS = 1e18;

    IERC20Mintable public immutable usdc;
    IERC20Mintable public immutable btc;
    IERC20Mintable public immutable eth;
    IERC20Mintable public immutable sol;
    IERC20Mintable public immutable gold;
    IERC20Mintable public immutable silver;
    IERC20Mintable public immutable platinum;
    IOracle public immutable oracle;

    mapping(address => bool) public claimed;

    constructor(
        address _usdc, address _btc, address _eth, address _sol,
        address _gold, address _silver, address _platinum, address _oracle
    ) {
        if (_usdc == address(0)) revert ZeroAddress();
        if (_btc == address(0)) revert ZeroAddress();
        if (_eth == address(0)) revert ZeroAddress();
        if (_sol == address(0)) revert ZeroAddress();
        if (_gold == address(0)) revert ZeroAddress();
        if (_silver == address(0)) revert ZeroAddress();
        if (_platinum == address(0)) revert ZeroAddress();
        if (_oracle == address(0)) revert ZeroAddress();
        usdc = IERC20Mintable(_usdc); btc = IERC20Mintable(_btc); eth = IERC20Mintable(_eth); sol = IERC20Mintable(_sol);
        gold = IERC20Mintable(_gold); silver = IERC20Mintable(_silver); platinum = IERC20Mintable(_platinum);
        oracle = IOracle(_oracle);
    }

    function claim() external {
        if (claimed[msg.sender]) revert AlreadyClaimed();
        if (oracle.isStale()) revert StaleOracle();
        uint256 ethPrice = oracle.getEthUsd(); uint256 btcPrice = oracle.getBtcUsd(); uint256 solPrice = oracle.getSolUsd();
        uint256 goldPrice = oracle.getGoldPricePerGram(); uint256 silverPrice = oracle.getSilverPricePerGram();
        uint256 platinumPrice = oracle.getPlatinumPricePerGram();
        if (ethPrice == 0 || btcPrice == 0 || solPrice == 0 || goldPrice == 0 || silverPrice == 0 || platinumPrice == 0) revert ZeroPrice();

        uint256 amtUSDC = TARGET_USD * TOKEN_DECIMALS;
        uint256 amtBTC  = (TARGET_USD * TOKEN_DECIMALS * PRICE_DECIMALS) / btcPrice;
        uint256 amtETH  = (TARGET_USD * TOKEN_DECIMALS * PRICE_DECIMALS) / ethPrice;
        uint256 amtSOL  = (TARGET_USD * TOKEN_DECIMALS * PRICE_DECIMALS) / solPrice;
        uint256 amtGold = (TARGET_USD * TOKEN_DECIMALS * TOKEN_DECIMALS) / goldPrice;
        uint256 amtSilver = (TARGET_USD * TOKEN_DECIMALS * TOKEN_DECIMALS) / silverPrice;
        uint256 amtPlatinum = (TARGET_USD * TOKEN_DECIMALS * TOKEN_DECIMALS) / platinumPrice;

        claimed[msg.sender] = true;
        usdc.mint(msg.sender, amtUSDC); btc.mint(msg.sender, amtBTC); eth.mint(msg.sender, amtETH); sol.mint(msg.sender, amtSOL);
        gold.mint(msg.sender, amtGold); silver.mint(msg.sender, amtSilver); platinum.mint(msg.sender, amtPlatinum);
        emit Claimed(msg.sender, amtUSDC, amtBTC, amtETH, amtSOL, amtGold, amtSilver, amtPlatinum);
    }
}

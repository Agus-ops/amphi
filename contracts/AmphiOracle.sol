// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AmphiOracle {
    event PriceUpdated(uint256 ethUsd, uint256 btcUsd, uint256 xauUsd, uint256 timestamp);
    event OracleKeeperChanged(address indexed oldKeeper, address indexed newKeeper);

    uint256 public ethUsd;
    uint256 public btcUsd;
    uint256 public xauUsd;
    uint256 public lastUpdate;
    address public oracleKeeper;

    uint256 public constant STALENESS_THRESHOLD = 30 minutes;
    uint256 private constant GRAMS_PER_TROY_OUNCE = 311035;
    uint256 private constant PRICE_DECIMALS = 1e8;
    uint256 private constant GRAM_PRECISION = 1e18;

    modifier onlyKeeper() { require(msg.sender == oracleKeeper, "ONLY_KEEPER"); _; }

    constructor(address _keeper, uint256 _initEth, uint256 _initBtc, uint256 _initXau) {
        require(_keeper != address(0), "ZERO_KEEPER");
        oracleKeeper = _keeper;
        if (_initEth > 0 && _initBtc > 0 && _initXau > 0) {
            ethUsd = _initEth;
            btcUsd = _initBtc;
            xauUsd = _initXau;
            lastUpdate = block.timestamp;
        }
    }

    function updatePrices(uint256 _ethUsd, uint256 _btcUsd, uint256 _xauUsd) external onlyKeeper {
        require(_ethUsd > 0 && _btcUsd > 0 && _xauUsd > 0, "ZERO_PRICE");
        ethUsd = _ethUsd;
        btcUsd = _btcUsd;
        xauUsd = _xauUsd;
        lastUpdate = block.timestamp;
        emit PriceUpdated(_ethUsd, _btcUsd, _xauUsd, block.timestamp);
    }

    function setOracleKeeper(address _newKeeper) external onlyKeeper {
        require(_newKeeper != address(0), "ZERO_KEEPER");
        emit OracleKeeperChanged(oracleKeeper, _newKeeper);
        oracleKeeper = _newKeeper;
    }

    function getPrices() external view returns (uint256, uint256, uint256, uint256) {
        return (ethUsd, btcUsd, xauUsd, lastUpdate);
    }

    function isStale() external view returns (bool) {
        return (block.timestamp - lastUpdate > STALENESS_THRESHOLD);
    }

    function getGoldPricePerGram() external view returns (uint256) {
        require(xauUsd > 0, "XAU_NOT_SET");
        require(block.timestamp - lastUpdate <= STALENESS_THRESHOLD, "STALE");
        uint256 numerator = xauUsd * GRAM_PRECISION * 1e4;
        uint256 denominator = GRAMS_PER_TROY_OUNCE * PRICE_DECIMALS;
        return numerator / denominator;
    }
}

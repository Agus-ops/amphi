// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AmphiOracle {
    error OnlyKeeper();
    error OnlyOwner();
    error OnlyPendingKeeper();
    error ZeroAddress();
    error ZeroPrice();
    error DeviationTooHigh();
    error StaleFeed();
    error FeedNotSet();

    event CryptoPricesUpdated(uint256 ethUsd, uint256 btcUsd, uint256 solUsd, uint256 timestamp);
    event CommodityPricesUpdated(uint256 xauUsd, uint256 xagUsd, uint256 xptUsd, uint256 timestamp);
    event OracleKeeperChanged(address indexed oldKeeper, address indexed newKeeper);
    event KeeperProposed(address indexed proposedKeeper);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    uint256 public ethUsd;
    uint256 public btcUsd;
    uint256 public solUsd;
    uint256 public xauUsd;
    uint256 public xagUsd;
    uint256 public xptUsd;
    uint256 public lastUpdate;

    mapping(uint8 => uint256) public feedLastUpdate;
    uint8 public constant FEED_ETH = 0;
    uint8 public constant FEED_BTC = 1;
    uint8 public constant FEED_SOL = 2;
    uint8 public constant FEED_XAU = 3;
    uint8 public constant FEED_XAG = 4;
    uint8 public constant FEED_XPT = 5;

    address public oracleKeeper;
    address public pendingKeeper;
    address public owner;

    uint256 public constant STALENESS_THRESHOLD = 30 minutes;
    uint256 public constant MAX_DEVIATION_BPS = 2000;
    uint256 private constant GRAMS_PER_TROY_OUNCE = 311035;
    uint256 private constant PRICE_DECIMALS = 1e8;
    uint256 private constant GRAM_PRECISION = 1e18;

    modifier onlyKeeper() { if (msg.sender != oracleKeeper) revert OnlyKeeper(); _; }
    modifier onlyOwner() { if (msg.sender != owner) revert OnlyOwner(); _; }

    constructor(address _keeper, address _owner) {
        if (_keeper == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();
        oracleKeeper = _keeper;
        owner = _owner;
    }

    function updateCryptoPrices(uint256 _ethUsd, uint256 _btcUsd, uint256 _solUsd) external onlyKeeper {
        if (_ethUsd == 0 || _btcUsd == 0 || _solUsd == 0) revert ZeroPrice();
        _checkDeviation(ethUsd, _ethUsd);
        _checkDeviation(btcUsd, _btcUsd);
        _checkDeviation(solUsd, _solUsd);
        ethUsd = _ethUsd; btcUsd = _btcUsd; solUsd = _solUsd;
        feedLastUpdate[FEED_ETH] = block.timestamp;
        feedLastUpdate[FEED_BTC] = block.timestamp;
        feedLastUpdate[FEED_SOL] = block.timestamp;
        lastUpdate = block.timestamp;
        emit CryptoPricesUpdated(_ethUsd, _btcUsd, _solUsd, block.timestamp);
    }

    function updateCommodityPrices(uint256 _xauUsd, uint256 _xagUsd, uint256 _xptUsd) external onlyKeeper {
        if (_xauUsd == 0 || _xagUsd == 0 || _xptUsd == 0) revert ZeroPrice();
        _checkDeviation(xauUsd, _xauUsd);
        _checkDeviation(xagUsd, _xagUsd);
        _checkDeviation(xptUsd, _xptUsd);
        xauUsd = _xauUsd; xagUsd = _xagUsd; xptUsd = _xptUsd;
        feedLastUpdate[FEED_XAU] = block.timestamp;
        feedLastUpdate[FEED_XAG] = block.timestamp;
        feedLastUpdate[FEED_XPT] = block.timestamp;
        lastUpdate = block.timestamp;
        emit CommodityPricesUpdated(_xauUsd, _xagUsd, _xptUsd, block.timestamp);
    }

    function proposeNewKeeper(address _newKeeper) external onlyKeeper {
        if (_newKeeper == address(0)) revert ZeroAddress();
        pendingKeeper = _newKeeper;
        emit KeeperProposed(_newKeeper);
    }

    function acceptNewKeeper() external {
        if (msg.sender != pendingKeeper) revert OnlyPendingKeeper();
        emit OracleKeeperChanged(oracleKeeper, pendingKeeper);
        oracleKeeper = pendingKeeper;
        pendingKeeper = address(0);
    }

    function emergencySetKeeper(address _newKeeper) external onlyOwner {
        if (_newKeeper == address(0)) revert ZeroAddress();
        pendingKeeper = address(0);
        emit OracleKeeperChanged(oracleKeeper, _newKeeper);
        oracleKeeper = _newKeeper;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function isStale() external view returns (bool) { return (block.timestamp - lastUpdate > STALENESS_THRESHOLD); }
    function isFeedStale(uint8 feedId) external view returns (bool) {
        uint256 last = feedLastUpdate[feedId];
        if (last == 0) return true;
        return (block.timestamp - last > STALENESS_THRESHOLD);
    }

    function getGoldPricePerGram() external view returns (uint256) {
        if (xauUsd == 0) revert FeedNotSet();
        if (block.timestamp - feedLastUpdate[FEED_XAU] > STALENESS_THRESHOLD) revert StaleFeed();
        return _toGram(xauUsd);
    }
    function getSilverPricePerGram() external view returns (uint256) {
        if (xagUsd == 0) revert FeedNotSet();
        if (block.timestamp - feedLastUpdate[FEED_XAG] > STALENESS_THRESHOLD) revert StaleFeed();
        return _toGram(xagUsd);
    }
    function getPlatinumPricePerGram() external view returns (uint256) {
        if (xptUsd == 0) revert FeedNotSet();
        if (block.timestamp - feedLastUpdate[FEED_XPT] > STALENESS_THRESHOLD) revert StaleFeed();
        return _toGram(xptUsd);
    }

    function getEthUsd() external view returns (uint256) {
        if (ethUsd == 0) revert FeedNotSet();
        if (block.timestamp - feedLastUpdate[FEED_ETH] > STALENESS_THRESHOLD) revert StaleFeed();
        return ethUsd;
    }
    function getBtcUsd() external view returns (uint256) {
        if (btcUsd == 0) revert FeedNotSet();
        if (block.timestamp - feedLastUpdate[FEED_BTC] > STALENESS_THRESHOLD) revert StaleFeed();
        return btcUsd;
    }
    function getSolUsd() external view returns (uint256) {
        if (solUsd == 0) revert FeedNotSet();
        if (block.timestamp - feedLastUpdate[FEED_SOL] > STALENESS_THRESHOLD) revert StaleFeed();
        return solUsd;
    }

    function _toGram(uint256 pricePerTroyOunce) private pure returns (uint256) {
        uint256 numerator = pricePerTroyOunce * GRAM_PRECISION * 1e4;
        uint256 denominator = GRAMS_PER_TROY_OUNCE * PRICE_DECIMALS;
        return numerator / denominator;
    }

    function _checkDeviation(uint256 oldPrice, uint256 newPrice) private pure {
        if (oldPrice == 0) return;
        uint256 diff = oldPrice > newPrice ? oldPrice - newPrice : newPrice - oldPrice;
        if (diff * 10000 / oldPrice > MAX_DEVIATION_BPS) revert DeviationTooHigh();
    }
}

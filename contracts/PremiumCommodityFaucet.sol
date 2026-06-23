// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IShared.sol";

contract PremiumCommodityFaucet {
    error ZeroAddress();
    error ZeroPayment();
    error ExceedsTxLimit();
    error ExceedsDailyLimit();
    error CommodityPaused();
    error FeeTransferFailed();
    error RewardTransferFailed();
    error OnlyMultisig();
    error ReentrancyGuard();

    event CommodityPurchased(address indexed user, string commodity, uint256 ethPaid, uint256 tokenAmount, uint256 fee);
    event CommodityPauseChanged(string commodity, bool paused);

    IERC20Mintable public immutable gold;
    IERC20Mintable public immutable silver;
    IERC20Mintable public immutable platinum;
    IOracle public immutable oracle;
    ICommodityVault public immutable goldVault;
    ICommodityVault public immutable silverVault;
    ICommodityVault public immutable platinumVault;
    address public immutable multisig;

    uint256 public constant TARGET_USD_PER_TX = 1000 * 1e8;
    uint256 public constant MAX_DAILY_USD = 2000 * 1e8;
    uint256 public constant FEE_BPS = 150;

    mapping(address => uint256) public dailySpent;
    mapping(address => uint256) public lastDay;
    mapping(bytes32 => bool) public paused;
    uint256 private _locked = 1;

    bytes32 private constant GOLD_ID = keccak256("gold");
    bytes32 private constant SILVER_ID = keccak256("silver");
    bytes32 private constant PLATINUM_ID = keccak256("platinum");

    modifier nonReentrant() { if (_locked == 2) revert ReentrancyGuard(); _locked = 2; _; _locked = 1; }

    constructor(
        address _gold, address _silver, address _platinum, address _oracle,
        address _goldVault, address _silverVault, address _platinumVault, address _multisig
    ) {
        if (_gold == address(0)) revert ZeroAddress();
        if (_silver == address(0)) revert ZeroAddress();
        if (_platinum == address(0)) revert ZeroAddress();
        if (_oracle == address(0)) revert ZeroAddress();
        if (_goldVault == address(0)) revert ZeroAddress();
        if (_silverVault == address(0)) revert ZeroAddress();
        if (_platinumVault == address(0)) revert ZeroAddress();
        if (_multisig == address(0)) revert ZeroAddress();
        gold = IERC20Mintable(_gold); silver = IERC20Mintable(_silver); platinum = IERC20Mintable(_platinum);
        oracle = IOracle(_oracle);
        goldVault = ICommodityVault(_goldVault); silverVault = ICommodityVault(_silverVault); platinumVault = ICommodityVault(_platinumVault);
        multisig = _multisig;
    }

    function mintGold() external payable nonReentrant { if (paused[GOLD_ID]) revert CommodityPaused(); _mint("gold", GOLD_ID, gold, goldVault, oracle.getGoldPricePerGram()); }
    function mintSilver() external payable nonReentrant { if (paused[SILVER_ID]) revert CommodityPaused(); _mint("silver", SILVER_ID, silver, silverVault, oracle.getSilverPricePerGram()); }
    function mintPlatinum() external payable nonReentrant { if (paused[PLATINUM_ID]) revert CommodityPaused(); _mint("platinum", PLATINUM_ID, platinum, platinumVault, oracle.getPlatinumPricePerGram()); }

    function _mint(string memory name, bytes32 id, IERC20Mintable token, ICommodityVault vault, uint256 pricePerGram) private {
        if (msg.value == 0) revert ZeroPayment();
        uint256 ethUsd = oracle.getEthUsd();
        uint256 usdValue = (msg.value * ethUsd) / 1e18;
        if (usdValue > TARGET_USD_PER_TX) revert ExceedsTxLimit();
        uint256 today = block.timestamp / 1 days;
        if (lastDay[msg.sender] != today) { lastDay[msg.sender] = today; dailySpent[msg.sender] = 0; }
        dailySpent[msg.sender] += usdValue;
        if (dailySpent[msg.sender] > MAX_DAILY_USD) revert ExceedsDailyLimit();
        uint256 fee = (msg.value * FEE_BPS) / 10000; uint256 net = msg.value - fee;
        uint256 tokenAmt = (net * ethUsd * 1e10) / pricePerGram;
        if (fee > 0) { (bool ok,) = multisig.call{value: fee}(""); if (!ok) revert FeeTransferFailed(); }
        address rp = vault.getRewardPool(); (bool ok2,) = rp.call{value: net}(""); if (!ok2) revert RewardTransferFailed();
        vault.injectRewards(net);
        token.mint(msg.sender, tokenAmt);
        emit CommodityPurchased(msg.sender, name, msg.value, tokenAmt, fee);
    }

    function setPause(bytes32 id, bool _paused) external { if (msg.sender != multisig) revert OnlyMultisig(); paused[id] = _paused; }
    function setPauseByName(string calldata c, bool _paused) external { if (msg.sender != multisig) revert OnlyMultisig(); paused[keccak256(bytes(c))] = _paused; }
}

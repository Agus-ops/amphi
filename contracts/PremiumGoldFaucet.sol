// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Interfaces.sol";

contract PremiumGoldFaucet {
    event Minted(address indexed user, uint256 ethPaid, uint256 goldMinted, uint256 rewardInjected);

    IERC20Mintable public immutable gold;
    IOracle public immutable oracle;
    address public immutable rewardPool;
    IGoldVault public immutable goldVault;

    uint256 public constant MAX_PER_TX = 1 ether;
    uint256 public constant MAX_PER_DAY = 5 ether;

    mapping(address => uint256) public dailyTotal;
    mapping(address => uint256) public lastDay;

    constructor(address _gold, address _oracle, address _rewardPool, address _goldVault) {
        require(_gold != address(0), "ZERO_GOLD");
        require(_oracle != address(0), "ZERO_ORACLE");
        require(_rewardPool != address(0), "ZERO_REWARD");
        require(_goldVault != address(0), "ZERO_VAULT");
        gold = IERC20Mintable(_gold);
        oracle = IOracle(_oracle);
        rewardPool = _rewardPool;
        goldVault = IGoldVault(_goldVault);
    }

    function mintGold() external payable {
        require(msg.value > 0, "NO_ETH");
        require(msg.value <= MAX_PER_TX, "TX_LIMIT");

        uint256 day = block.timestamp / 1 days;
        if (lastDay[msg.sender] != day) {
            lastDay[msg.sender] = day;
            dailyTotal[msg.sender] = 0;
        }

        dailyTotal[msg.sender] += msg.value;
        require(dailyTotal[msg.sender] <= MAX_PER_DAY, "DAILY_LIMIT");

        uint256 pricePerGram = oracle.getGoldPricePerGram();
        uint256 goldAmount = (msg.value * 1e18) / pricePerGram;
        require(goldAmount > 0, "TOO_SMALL");

        gold.mint(msg.sender, goldAmount);

        (bool ok, ) = rewardPool.call{value: msg.value}("");
        require(ok, "REWARD_SEND_FAIL");

        goldVault.injectRewards(msg.value);

        emit Minted(msg.sender, msg.value, goldAmount, msg.value);
    }
}

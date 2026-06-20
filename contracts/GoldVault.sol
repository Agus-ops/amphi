// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GoldVault {
    event Locked(address indexed user, uint256 amount, uint256 duration, uint256 unlockTime);
    event Unlocked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardsAdded(uint256 amount);
    event AuthorizedInjectorSet(address indexed injector);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address public immutable gold;
    address public immutable rewardPool;

    uint256 public rewardPerWeightStored;
    uint256 public totalWeightedLocked;

    uint256 public constant DURATION_7  = 7 days;
    uint256 public constant DURATION_15 = 15 days;
    uint256 public constant DURATION_30 = 30 days;
    uint256 public constant WEIGHT_7  = 1e18;
    uint256 public constant WEIGHT_15 = 1.5e18;
    uint256 public constant WEIGHT_30 = 2e18;

    struct Position {
        uint256 amount;
        uint256 weight;
        uint256 unlockTime;
        uint256 rewardPerWeightPaid;
    }
    mapping(address => Position) public positions;

    address public authorizedInjector;
    address public owner;

    modifier onlyAuthorized() { require(msg.sender == authorizedInjector, "NOT_AUTHORIZED"); _; }
    modifier onlyOwner() { require(msg.sender == owner, "ONLY_OWNER"); _; }

    constructor(address _gold, address _rewardPool, address _owner) {
        require(_gold != address(0), "ZERO_GOLD");
        require(_rewardPool != address(0), "ZERO_REWARD");
        require(_owner != address(0), "ZERO_OWNER");
        gold = _gold;
        rewardPool = _rewardPool;
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    function lock(uint256 amount, uint256 duration) external {
        require(amount > 0, "ZERO_AMOUNT");
        require(duration == DURATION_7 || duration == DURATION_15 || duration == DURATION_30, "INVALID_DURATION");
        Position storage pos = positions[msg.sender];
        require(pos.amount == 0, "ALREADY_LOCKED");
        uint256 weight = _getWeight(duration);
        uint256 unlockTime = block.timestamp + duration;
        _safeTransferFrom(gold, msg.sender, address(this), amount);
        pos.amount = amount;
        pos.weight = weight;
        pos.unlockTime = unlockTime;
        pos.rewardPerWeightPaid = rewardPerWeightStored;
        totalWeightedLocked += amount * weight / 1e18;
        emit Locked(msg.sender, amount, duration, unlockTime);
    }

    function unlock() external {
        Position storage pos = positions[msg.sender];
        require(pos.amount > 0, "NO_POSITION");
        require(block.timestamp >= pos.unlockTime, "NOT_MATURE");
        uint256 amount = pos.amount;
        uint256 reward = _pendingReward(msg.sender);
        totalWeightedLocked -= amount * pos.weight / 1e18;
        delete positions[msg.sender];
        _safeTransfer(gold, msg.sender, amount);
        emit Unlocked(msg.sender, amount);
        if (reward > 0) {
            _pullReward(reward);
            (bool ok, ) = msg.sender.call{value: reward}("");
            require(ok, "ETH_SEND_FAILED");
            emit RewardClaimed(msg.sender, reward);
        }
    }

    function claimReward() external {
        Position storage pos = positions[msg.sender];
        require(pos.amount > 0, "NO_POSITION");
        require(block.timestamp >= pos.unlockTime, "NOT_MATURE");
        uint256 reward = _pendingReward(msg.sender);
        require(reward > 0, "NO_REWARD");
        pos.rewardPerWeightPaid = rewardPerWeightStored;
        _pullReward(reward);
        (bool ok, ) = msg.sender.call{value: reward}("");
        require(ok, "ETH_SEND_FAILED");
        emit RewardClaimed(msg.sender, reward);
    }

    function injectRewards(uint256 amount) external onlyAuthorized {
        require(amount > 0, "ZERO_AMOUNT");
        require(totalWeightedLocked > 0, "NO_LOCKERS");
        rewardPerWeightStored += amount * 1e18 / totalWeightedLocked;
        emit RewardsAdded(amount);
    }

    function setAuthorizedInjector(address _injector) external onlyOwner {
        require(_injector != address(0), "ZERO_INJECTOR");
        require(authorizedInjector == address(0), "ALREADY_SET");
        authorizedInjector = _injector;
        emit AuthorizedInjectorSet(_injector);
    }

    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function _getWeight(uint256 duration) internal pure returns (uint256) {
        if (duration == DURATION_7) return WEIGHT_7;
        if (duration == DURATION_15) return WEIGHT_15;
        return WEIGHT_30;
    }

    function _pendingReward(address user) internal view returns (uint256) {
        Position storage pos = positions[user];
        if (pos.amount == 0) return 0;
        uint256 weighted = pos.amount * pos.weight / 1e18;
        return weighted * (rewardPerWeightStored - pos.rewardPerWeightPaid) / 1e18;
    }

    function _pullReward(uint256 amount) internal {
        (bool ok, ) = rewardPool.call(abi.encodeWithSignature("claimRewards(uint256)", amount));
        require(ok, "PULL_REWARD_FAILED");
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, ) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));
        require(ok, "TRANSFER_FAILED");
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, ) = token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount));
        require(ok, "TRANSFER_FROM_FAILED");
    }

    function pendingReward(address user) external view returns (uint256) { return _pendingReward(user); }
    receive() external payable {}
}

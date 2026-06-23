// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CommodityVault
/// @notice Time-locked staking for a single commodity (Gold, Silver, or Platinum).
/// @dev Deployed 3 times with different token/rewardPool parameters.
///      Reward accounting uses MasterChef-style rewardPerWeightStored.
///      ETH stays in RewardPool; vault pulls on unlock/claim.
///      Pending rewards are queued if no lockers exist.
contract CommodityVault {
    // ─────────────────────────────────────────────────────────
    // Custom Errors
    // ─────────────────────────────────────────────────────────
    error ZeroAddress();
    error ZeroAmount();
    error InvalidDuration();
    error AlreadyLocked();
    error NoPosition();
    error NotMature();
    error NoReward();
    error NotAuthorized();
    error InjectorAlreadySet();
    error TransferFailed();
    error PullRewardFailed();
    error ReentrancyGuard();

    // ─────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────
    event Locked(address indexed user, uint256 amount, uint256 duration, uint256 unlockTime);
    event Unlocked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardsAdded(uint256 amount);
    event AuthorizedInjectorSet(address indexed injector);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event EthSwept(address indexed to, uint256 amount);

    // ─────────────────────────────────────────────────────────
    // Immutables
    // ─────────────────────────────────────────────────────────
    address public immutable commodityToken;
    address public immutable rewardPool;

    // ─────────────────────────────────────────────────────────
    // Reward Accounting
    // ─────────────────────────────────────────────────────────
    uint256 public rewardPerWeightStored;
    uint256 public totalWeightedLocked;
    uint256 public pendingRewards; // rewards waiting for lockers

    // ─────────────────────────────────────────────────────────
    // Lock Durations & Weights
    // ─────────────────────────────────────────────────────────
    uint256 public constant DURATION_7  = 7 days;
    uint256 public constant DURATION_15 = 15 days;
    uint256 public constant DURATION_30 = 30 days;
    uint256 public constant WEIGHT_7  = 1e18;    // 1.0x
    uint256 public constant WEIGHT_15 = 1.5e18;  // 1.5x
    uint256 public constant WEIGHT_30 = 2e18;    // 2.0x

    // ─────────────────────────────────────────────────────────
    // User Positions
    // ─────────────────────────────────────────────────────────
    struct Position {
        uint256 amount;
        uint256 weight;
        uint256 unlockTime;
        uint256 rewardPerWeightPaid;
    }
    mapping(address => Position) public positions;

    // ─────────────────────────────────────────────────────────
    // Access Control
    // ─────────────────────────────────────────────────────────
    address public authorizedInjector;
    address public owner;
    uint256 private _locked = 1;

    modifier onlyInjector() {
        if (msg.sender != authorizedInjector) revert NotAuthorized();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier nonReentrant() {
        if (_locked == 2) revert ReentrancyGuard();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ─────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────
    constructor(address _commodityToken, address _rewardPool, address _owner) {
        if (_commodityToken == address(0)) revert ZeroAddress();
        if (_rewardPool == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();
        commodityToken = _commodityToken;
        rewardPool = _rewardPool;
        owner = _owner;
    }

    // ─────────────────────────────────────────────────────────
    // Lock
    // ─────────────────────────────────────────────────────────
    function lock(uint256 amount, uint256 duration) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (duration != DURATION_7 && duration != DURATION_15 && duration != DURATION_30)
            revert InvalidDuration();

        Position storage pos = positions[msg.sender];
        if (pos.amount > 0) revert AlreadyLocked();

        uint256 weight = _getWeight(duration);
        uint256 unlockTime = block.timestamp + duration;

        // Distribute pending rewards before new locker enters
        _distributePendingRewards();

        // Effects first (before external call)
        pos.amount = amount;
        pos.weight = weight;
        pos.unlockTime = unlockTime;
        pos.rewardPerWeightPaid = rewardPerWeightStored;
        totalWeightedLocked += amount * weight / 1e18;

        // Interaction last
        _safeTransferFrom(commodityToken, msg.sender, address(this), amount);

        emit Locked(msg.sender, amount, duration, unlockTime);
    }

    // ─────────────────────────────────────────────────────────
    // Unlock
    // ─────────────────────────────────────────────────────────
    function unlock() external nonReentrant {
        Position storage pos = positions[msg.sender];
        if (pos.amount == 0) revert NoPosition();
        if (block.timestamp < pos.unlockTime) revert NotMature();

        uint256 amount = pos.amount;
        uint256 reward = _pendingReward(msg.sender);

        // Effects first
        totalWeightedLocked -= amount * pos.weight / 1e18;
        delete positions[msg.sender];

        // Transfer commodity back
        _safeTransfer(commodityToken, msg.sender, amount);
        emit Unlocked(msg.sender, amount);

        // Transfer ETH reward (if any)
        if (reward > 0) {
            _pullReward(reward);
            (bool ok, ) = msg.sender.call{value: reward}("");
            if (!ok) revert TransferFailed();
            emit RewardClaimed(msg.sender, reward);
        }
    }

    // ─────────────────────────────────────────────────────────
    // Claim Reward Only
    // ─────────────────────────────────────────────────────────
    function claimReward() external nonReentrant {
        Position storage pos = positions[msg.sender];
        if (pos.amount == 0) revert NoPosition();
        if (block.timestamp < pos.unlockTime) revert NotMature();

        uint256 reward = _pendingReward(msg.sender);
        if (reward == 0) revert NoReward();

        pos.rewardPerWeightPaid = rewardPerWeightStored;

        _pullReward(reward);
        (bool ok, ) = msg.sender.call{value: reward}("");
        if (!ok) revert TransferFailed();
        emit RewardClaimed(msg.sender, reward);
    }

    // ─────────────────────────────────────────────────────────
    // Reward Injection (called by PremiumCommodityFaucet)
    // ─────────────────────────────────────────────────────────
    function injectRewards(uint256 amount) external onlyInjector {
        if (amount == 0) revert ZeroAmount();
        pendingRewards += amount;
        
        if (totalWeightedLocked > 0) {
            rewardPerWeightStored += pendingRewards * 1e18 / totalWeightedLocked;
            emit RewardsAdded(pendingRewards);
            pendingRewards = 0;
        }
        // If no lockers, rewards stay in pendingRewards until next lock()
    }

    // ─────────────────────────────────────────────────────────
    // Admin
    // ─────────────────────────────────────────────────────────

    function setAuthorizedInjector(address _injector) external onlyOwner {
        if (_injector == address(0)) revert ZeroAddress();
        if (authorizedInjector != address(0)) revert InjectorAlreadySet();
        authorizedInjector = _injector;
        emit AuthorizedInjectorSet(_injector);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    /// @notice Recover accidentally sent ETH (not reward ETH).
    function sweepETH() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert ZeroAmount();
        (bool ok, ) = owner.call{value: balance}("");
        if (!ok) revert TransferFailed();
        emit EthSwept(owner, balance);
    }

    // ─────────────────────────────────────────────────────────
    // Public Views
    // ─────────────────────────────────────────────────────────

    function pendingReward(address user) external view returns (uint256) {
        return _pendingReward(user);
    }

    function getRewardPool() external view returns (address) {
        return rewardPool;
    }

    // ─────────────────────────────────────────────────────────
    // Internal
    // ─────────────────────────────────────────────────────────

    function _distributePendingRewards() internal {
        if (totalWeightedLocked > 0 && pendingRewards > 0) {
            rewardPerWeightStored += pendingRewards * 1e18 / totalWeightedLocked;
            emit RewardsAdded(pendingRewards);
            pendingRewards = 0;
        }
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
        (bool ok, ) = rewardPool.call(
            abi.encodeWithSignature("claimRewards(uint256)", amount)
        );
        if (!ok) revert PullRewardFailed();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount)
        );
        if (!ok || (data.length > 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    receive() external payable { }
}

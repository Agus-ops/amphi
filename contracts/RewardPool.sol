// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title RewardPool
/// @notice ETH sink for a single commodity vault.
/// @dev Receives ETH from PremiumCommodityFaucet. Only the registered vault can withdraw.
///      Vault address can be set once by the owner. No admin withdraw of user funds.
contract RewardPool {
    // ─────────────────────────────────────────────────────────
    // Custom Errors
    // ─────────────────────────────────────────────────────────
    error ZeroAddress();
    error ZeroAmount();
    error NotAuthorized();
    error VaultAlreadySet();
    error InsufficientBalance();
    error TransferFailed();

    // ─────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────
    event Received(address indexed from, uint256 amount);
    event VaultSet(address indexed vault);
    event RewardsClaimed(address indexed vault, uint256 amount);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    // ─────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────
    address public vault;
    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotAuthorized();
        _;
    }

    modifier onlyVault() {
        if (msg.sender != vault) revert NotAuthorized();
        _;
    }

    // ─────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────
    constructor(address _owner) {
        if (_owner == address(0)) revert ZeroAddress();
        owner = _owner;
    }

    // ─────────────────────────────────────────────────────────
    // Vault Setup (one-time)
    // ─────────────────────────────────────────────────────────
    function setVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert ZeroAddress();
        if (vault != address(0)) revert VaultAlreadySet();
        vault = _vault;
        emit VaultSet(_vault);
    }

    // ─────────────────────────────────────────────────────────
    // Reward Distribution (only by vault)
    // ─────────────────────────────────────────────────────────
    function claimRewards(uint256 amount) external onlyVault {
        if (amount == 0) revert ZeroAmount();
        if (address(this).balance < amount) revert InsufficientBalance();
        (bool ok, ) = vault.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit RewardsClaimed(vault, amount);
    }

    // ─────────────────────────────────────────────────────────
    // ETH Reception (from PremiumCommodityFaucet)
    // ─────────────────────────────────────────────────────────
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // ─────────────────────────────────────────────────────────
    // Admin
    // ─────────────────────────────────────────────────────────
    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    // ─────────────────────────────────────────────────────────
    // View
    // ─────────────────────────────────────────────────────────
    function totalRewards() external view returns (uint256) {
        return address(this).balance;
    }
}

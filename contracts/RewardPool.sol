// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RewardPool {
    event Received(address indexed from, uint256 amount);
    event VaultSet(address indexed oldVault, address indexed newVault);
    event RewardsClaimed(address indexed vault, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address public vault;
    address public owner;

    modifier onlyOwner() { require(msg.sender == owner, "ONLY_OWNER"); _; }
    modifier onlyVault() { require(msg.sender == vault, "ONLY_VAULT"); _; }

    constructor(address _vault, address _owner) {
        require(_owner != address(0), "ZERO_OWNER");
        vault = _vault;
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "ZERO_VAULT");
        emit VaultSet(vault, _vault);
        vault = _vault;
    }

    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZERO_OWNER");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function claimRewards(uint256 amount) external onlyVault {
        require(amount > 0, "ZERO_AMOUNT");
        require(address(this).balance >= amount, "INSUFFICIENT_BALANCE");
        (bool ok, ) = vault.call{value: amount}("");
        require(ok, "TRANSFER_FAILED");
        emit RewardsClaimed(vault, amount);
    }

    receive() external payable { emit Received(msg.sender, msg.value); }
    function totalRewards() external view returns (uint256) { return address(this).balance; }
}

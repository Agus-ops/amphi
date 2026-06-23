// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title AmphiRegistry
/// @notice On-chain registry of official tokens and pools.
/// @dev Helps frontend distinguish official vs community assets.
///      Supports batch registration to save gas during setup.
contract AmphiRegistry {
    error ZeroAddress();
    error NotOwner();
    error AlreadyRegistered();
    error NotRegistered();
    error LengthMismatch();

    event TokenRegistered(address indexed token, string symbol);
    event TokenRemoved(address indexed token);
    event PoolRegistered(address indexed pool, address token0, address token1);
    event PoolRemoved(address indexed pool);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    mapping(address => bool) public isOfficialToken;
    mapping(address => bool) public isOfficialPool;
    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // ── Single Token ──
    function registerToken(address token, string calldata symbol) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (isOfficialToken[token]) revert AlreadyRegistered();
        isOfficialToken[token] = true;
        emit TokenRegistered(token, symbol);
    }

    function removeToken(address token) external onlyOwner {
        if (!isOfficialToken[token]) revert NotRegistered();
        isOfficialToken[token] = false;
        emit TokenRemoved(token);
    }

    // ── Batch Token (gas saver) ──
    function registerTokens(address[] calldata tokens, string[] calldata symbols) external onlyOwner {
        if (tokens.length != symbols.length) revert LengthMismatch();
        for (uint256 i = 0; i < tokens.length; i++) {
            address t = tokens[i];
            if (t == address(0)) revert ZeroAddress();
            if (isOfficialToken[t]) revert AlreadyRegistered();
            isOfficialToken[t] = true;
            emit TokenRegistered(t, symbols[i]);
        }
    }

    // ── Single Pool ──
    function registerPool(address pool, address token0, address token1) external onlyOwner {
        if (pool == address(0)) revert ZeroAddress();
        if (isOfficialPool[pool]) revert AlreadyRegistered();
        isOfficialPool[pool] = true;
        emit PoolRegistered(pool, token0, token1);
    }

    function removePool(address pool) external onlyOwner {
        if (!isOfficialPool[pool]) revert NotRegistered();
        isOfficialPool[pool] = false;
        emit PoolRemoved(pool);
    }

    // ── Ownership ──
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

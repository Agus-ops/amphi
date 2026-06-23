// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AmphiPair.sol";

/// @title AmphiFactory
/// @notice Permissionless factory for creating AmphiPair liquidity pools.
/// @dev Uses CREATE2 for deterministic pair addresses.
///      Official pool curation is delegated to AmphiRegistry.
contract AmphiFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 pairIndex);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    address public owner;
    address public pendingOwner;

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // ─────────────────────────────────────────────────────────
    // Pair Creation (Permissionless)
    // ─────────────────────────────────────────────────────────
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "ZERO_ADDRESS");
        require(getPair[tokenA][tokenB] == address(0), "PAIR_EXISTS");

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        bytes memory bytecode = type(AmphiPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        require(pair != address(0), "CREATE2_FAILED");

        AmphiPair(pair).initialize(token0, token1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;

        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    // ─────────────────────────────────────────────────────────
    // Governance (Two-Step Ownership)
    // ─────────────────────────────────────────────────────────

    /// @notice Step 1: Current owner proposes a new owner.
    function proposeOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "ZERO_ADDRESS");
        pendingOwner = _newOwner;
    }

    /// @notice Step 2: Proposed owner accepts the role.
    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "ONLY_PENDING_OWNER");
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    // ─────────────────────────────────────────────────────────
    // Views
    // ─────────────────────────────────────────────────────────

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AmphiPair.sol";

contract AmphiFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    mapping(address => bool) public isOfficialPool;
    address public owner;

    modifier onlyOwner() { require(msg.sender == owner, "ONLY_OWNER"); _; }

    constructor() { owner = msg.sender; }

    function setOwner(address _owner) external onlyOwner { require(_owner != address(0), "ZERO_OWNER"); owner = _owner; }
    function markOfficialPool(address pair) external onlyOwner { isOfficialPool[pair] = true; }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "ZERO_ADDRESS");
        require(getPair[tokenA][tokenB] == address(0), "PAIR_EXISTS");

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        bytes memory bytecode = type(AmphiPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly { pair := create2(0, add(bytecode, 32), mload(bytecode), salt) }
        require(pair != address(0), "CREATE2_FAILED");

        AmphiPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}

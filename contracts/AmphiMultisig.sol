// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AmphiMultisig {
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event RequirementChanged(uint256 newRequirement);
    event TxSubmitted(uint256 indexed txId, address indexed submitter, address to, uint256 value, bytes data);
    event TxConfirmed(address indexed owner, uint256 indexed txId);
    event TxRevoked(address indexed owner, uint256 indexed txId);
    event TxExecuted(uint256 indexed txId);
    event Received(address indexed sender, uint256 amount);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmed;
    bool private _executing;

    modifier onlyOwner() { require(isOwner[msg.sender], "NOT_OWNER"); _; }
    modifier onlySelf() { require(msg.sender == address(this), "ONLY_SELF"); _; }
    modifier txExists(uint256 txId) { require(txId < transactions.length, "TX_NOT_FOUND"); _; }
    modifier notExecuted(uint256 txId) { require(!transactions[txId].executed, "ALREADY_EXECUTED"); _; }
    modifier noReentrant() { require(!_executing, "REENTRANCY"); _executing = true; _; _executing = false; }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "NO_OWNERS");
        require(_required > 0 && _required <= _owners.length, "INVALID_REQUIRED");
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "ZERO_ADDRESS");
            require(!isOwner[owner], "DUPLICATE_OWNER");
            isOwner[owner] = true;
            owners.push(owner);
            emit OwnerAdded(owner);
        }
        required = _required;
        emit RequirementChanged(_required);
    }

    function submitTransaction(address to, uint256 value, bytes calldata data) external onlyOwner returns (uint256) {
        require(to != address(0), "ZERO_TO");
        transactions.push(Transaction({to: to, value: value, data: data, executed: false, confirmations: 0}));
        uint256 txId = transactions.length - 1;
        emit TxSubmitted(txId, msg.sender, to, value, data);
        return txId;
    }

    function confirmTransaction(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) {
        require(!confirmed[txId][msg.sender], "ALREADY_CONFIRMED");
        confirmed[txId][msg.sender] = true;
        transactions[txId].confirmations += 1;
        emit TxConfirmed(msg.sender, txId);
    }

    function revokeConfirmation(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) {
        require(confirmed[txId][msg.sender], "NOT_CONFIRMED");
        confirmed[txId][msg.sender] = false;
        transactions[txId].confirmations -= 1;
        emit TxRevoked(msg.sender, txId);
    }

    function executeTransaction(uint256 txId) external onlyOwner txExists(txId) notExecuted(txId) noReentrant {
        Transaction storage txn = transactions[txId];
        require(txn.confirmations >= required, "INSUFFICIENT_CONFIRMATIONS");
        txn.executed = true;
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "TX_FAILED");
        emit TxExecuted(txId);
    }

    function addOwner(address newOwner) external onlySelf {
        require(newOwner != address(0), "ZERO_ADDRESS");
        require(!isOwner[newOwner], "DUPLICATE_OWNER");
        isOwner[newOwner] = true;
        owners.push(newOwner);
        emit OwnerAdded(newOwner);
    }

    function removeOwner(address owner) external onlySelf {
        require(isOwner[owner], "NOT_OWNER");
        require(owners.length - 1 >= required, "WOULD_LOCK_REQUIRED");
        isOwner[owner] = false;
        uint256 len = owners.length;
        for (uint256 i = 0; i < len; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[len - 1];
                owners.pop();
                break;
            }
        }
        emit OwnerRemoved(owner);
    }

    function changeRequirement(uint256 newRequired) external onlySelf {
        require(newRequired > 0 && newRequired <= owners.length, "INVALID_REQUIRED");
        required = newRequired;
        emit RequirementChanged(newRequired);
    }

    function getOwners() external view returns (address[] memory) { return owners; }
    function getTransactionCount() external view returns (uint256) { return transactions.length; }
    function getConfirmationCount(uint256 txId) external view txExists(txId) returns (uint256) { return transactions[txId].confirmations; }
    function isConfirmedBy(uint256 txId, address owner) external view txExists(txId) returns (bool) { return confirmed[txId][owner]; }

    receive() external payable { emit Received(msg.sender, msg.value); }
}

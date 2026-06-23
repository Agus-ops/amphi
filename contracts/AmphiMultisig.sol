// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title AmphiMultisig
/// @notice Multi-signature wallet with auto-confirm and auto-execute.
/// @dev Governance changes (add/remove owner, change requirement) MUST go
///      through the normal submit -> confirm -> execute flow (onlySelf pattern).
///      submitTransaction auto-confirms for the submitter.
///      confirmTransaction auto-executes if threshold is met.
contract AmphiMultisig {
    error NotOwner();
    error OnlySelf();
    error TxNotFound();
    error AlreadyExecuted();
    error Reentrancy();
    error ZeroAddress();
    error DuplicateOwner();
    error InsufficientConfirmations();
    error TxFailed();
    error NoOwners();
    error InvalidRequirement();
    error WouldLockRequired();

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

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    modifier onlySelf() {
        if (msg.sender != address(this)) revert OnlySelf();
        _;
    }

    modifier txExists(uint256 txId) {
        if (txId >= transactions.length) revert TxNotFound();
        _;
    }

    modifier notExecuted(uint256 txId) {
        if (transactions[txId].executed) revert AlreadyExecuted();
        _;
    }

    modifier noReentrant() {
        if (_executing) revert Reentrancy();
        _executing = true;
        _;
        _executing = false;
    }

    constructor(address[] memory _owners, uint256 _required) {
        if (_owners.length == 0) revert NoOwners();
        if (_required == 0 || _required > _owners.length) revert InvalidRequirement();

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            if (owner == address(0)) revert ZeroAddress();
            if (isOwner[owner]) revert DuplicateOwner();
            isOwner[owner] = true;
            owners.push(owner);
            emit OwnerAdded(owner);
        }
        required = _required;
        emit RequirementChanged(_required);
    }

    // ─────────────────────────────────────────────────────────
    // Core Flow
    // ─────────────────────────────────────────────────────────

    /// @notice Submit a transaction. Submitter is auto-confirmed.
    function submitTransaction(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner returns (uint256 txId) {
        if (to == address(0)) revert ZeroAddress();

        transactions.push(
            Transaction({
                to: to,
                value: value,
                data: data,
                executed: false,
                confirmations: 0
            })
        );

        txId = transactions.length - 1;

        // Auto-confirm for the submitter
        confirmed[txId][msg.sender] = true;
        transactions[txId].confirmations = 1;

        emit TxSubmitted(txId, msg.sender, to, value, data);
        emit TxConfirmed(msg.sender, txId);
    }

    /// @notice Confirm a transaction. Auto-executes if threshold is met.
    function confirmTransaction(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
    {
        if (confirmed[txId][msg.sender]) revert(); // silently revert (already confirmed)
        confirmed[txId][msg.sender] = true;
        transactions[txId].confirmations += 1;
        emit TxConfirmed(msg.sender, txId);

        // Auto-execute if threshold met
        if (transactions[txId].confirmations >= required) {
            _executeTransaction(txId);
        }
    }

    /// @notice Revoke a confirmation.
    function revokeConfirmation(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
    {
        if (!confirmed[txId][msg.sender]) revert(); // not confirmed
        confirmed[txId][msg.sender] = false;
        transactions[txId].confirmations -= 1;
        emit TxRevoked(msg.sender, txId);
    }

    /// @notice Manually execute a transaction (if threshold met).
    function executeTransaction(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
    {
        if (transactions[txId].confirmations < required) revert InsufficientConfirmations();
        _executeTransaction(txId);
    }

    /// @notice Internal execution logic (called by auto-execute or manual execute).
    function _executeTransaction(uint256 txId) internal noReentrant {
        Transaction storage txn = transactions[txId];
        if (txn.executed) revert AlreadyExecuted();
        txn.executed = true;
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        if (!success) revert TxFailed();
        emit TxExecuted(txId);
    }

    // ─────────────────────────────────────────────────────────
    // Self-Management (only via multisig flow)
    // ─────────────────────────────────────────────────────────

    function addOwner(address newOwner) external onlySelf {
        if (newOwner == address(0)) revert ZeroAddress();
        if (isOwner[newOwner]) revert DuplicateOwner();
        isOwner[newOwner] = true;
        owners.push(newOwner);
        emit OwnerAdded(newOwner);
    }

    function removeOwner(address owner) external onlySelf {
        if (!isOwner[owner]) revert NotOwner();
        if (owners.length - 1 < required) revert WouldLockRequired();
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
        if (newRequired == 0 || newRequired > owners.length) revert InvalidRequirement();
        required = newRequired;
        emit RequirementChanged(newRequired);
    }

    // ─────────────────────────────────────────────────────────
    // Views
    // ─────────────────────────────────────────────────────────

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function getConfirmationCount(uint256 txId)
        external
        view
        txExists(txId)
        returns (uint256)
    {
        return transactions[txId].confirmations;
    }

    function isConfirmedBy(uint256 txId, address owner)
        external
        view
        txExists(txId)
        returns (bool)
    {
        return confirmed[txId][owner];
    }

    /// @notice Get full transaction details including calldata.
    function getTransaction(uint256 txId)
        external
        view
        txExists(txId)
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmations
        )
    {
        Transaction storage txn = transactions[txId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.confirmations);
    }

    // ─────────────────────────────────────────────────────────
    // ETH Reception
    // ─────────────────────────────────────────────────────────

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title AmphiTimelock
/// @notice Timelock for governance transactions with 24-hour delay.
/// @dev Multisig queues transactions by index; after DELAY they become executable.
///      Transactions can be cancelled before execution.
///      Expired transactions (past GRACE_PERIOD) cannot be executed.
contract AmphiTimelock {
    error ZeroAddress();
    error NotMultisig();
    error TooEarly();
    error Expired();
    error TxAlreadyExecuted();
    error TxCancelled();
    error TxNotExists();
    error ExecutionFailed();

    event TransactionQueued(uint256 indexed txId, address target, uint256 value, bytes data, uint256 eta);
    event TransactionExecuted(uint256 indexed txId);
    event TransactionCancelled(uint256 indexed txId);

    uint256 public constant DELAY = 24 hours;
    uint256 public constant GRACE_PERIOD = 48 hours;

    address public immutable multisig;

    struct Tx {
        address target;
        uint256 value;
        bytes data;
        uint256 eta;
        bool executed;
        bool cancelled;
    }

    Tx[] public transactions;

    modifier onlyMultisig() {
        if (msg.sender != multisig) revert NotMultisig();
        _;
    }

    constructor(address _multisig) {
        if (_multisig == address(0)) revert ZeroAddress();
        multisig = _multisig;
    }

    /// @notice Queue a governance transaction. Callable only by Multisig.
    function queueTransaction(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyMultisig returns (uint256 txId) {
        if (target == address(0)) revert ZeroAddress();
        uint256 eta = block.timestamp + DELAY;
        transactions.push(Tx({
            target: target,
            value: value,
            data: data,
            eta: eta,
            executed: false,
            cancelled: false
        }));
        txId = transactions.length - 1;
        emit TransactionQueued(txId, target, value, data, eta);
    }

    /// @notice Execute a queued transaction after DELAY has passed.
    function executeTransaction(uint256 txId) external onlyMultisig {
        if (txId >= transactions.length) revert TxNotExists();
        Tx storage txn = transactions[txId];
        if (txn.executed) revert TxAlreadyExecuted();
        if (txn.cancelled) revert TxCancelled();
        if (block.timestamp < txn.eta) revert TooEarly();
        if (block.timestamp > txn.eta + GRACE_PERIOD) revert Expired();

        txn.executed = true;
        (bool ok, ) = txn.target.call{value: txn.value}(txn.data);
        if (!ok) revert ExecutionFailed();
        emit TransactionExecuted(txId);
    }

    /// @notice Cancel a queued transaction. Callable only by Multisig.
    function cancelTransaction(uint256 txId) external onlyMultisig {
        if (txId >= transactions.length) revert TxNotExists();
        Tx storage txn = transactions[txId];
        if (txn.executed) revert TxAlreadyExecuted();
        if (txn.cancelled) revert TxCancelled();
        txn.cancelled = true;
        emit TransactionCancelled(txId);
    }

    // ─────────────────────────────────────────────────────────
    // Views
    // ─────────────────────────────────────────────────────────

    function getTransaction(uint256 txId) external view returns (
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta,
        bool executed,
        bool cancelled
    ) {
        if (txId >= transactions.length) revert TxNotExists();
        Tx storage txn = transactions[txId];
        return (txn.target, txn.value, txn.data, txn.eta, txn.executed, txn.cancelled);
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    function isReady(uint256 txId) external view returns (bool) {
        if (txId >= transactions.length) return false;
        Tx storage txn = transactions[txId];
        return !txn.executed
            && !txn.cancelled
            && block.timestamp >= txn.eta
            && block.timestamp <= txn.eta + GRACE_PERIOD;
    }

    /// @notice Allow Timelock to receive ETH for governance transactions.
    receive() external payable { }
}

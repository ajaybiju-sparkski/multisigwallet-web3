// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    
    event Deposit(address indexed sender, uint amount);
    event TransactionProposed(uint indexed txId, address indexed to, uint value, bytes data);
    event TransactionApproved(address indexed owner, uint indexed txId);
    event TransactionExecuted(uint indexed txId);
    event TransactionRevoked(address indexed owner, uint indexed txId);

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint approvalCount;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public requiredApprovals;

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public approvals;
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier txExists(uint _txId) {
        require(_txId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notApproved(uint _txId) {
        require(!approvals[_txId][msg.sender], "Already approved");
        _;
    }

    modifier notExecuted(uint _txId) {
        require(!transactions[_txId].executed, "Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint _requiredApprovals) {
        require(_owners.length > 0, "Owners required");
        require(_requiredApprovals > 0 && _requiredApprovals <= _owners.length, "Invalid required approvals");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        requiredApprovals = _requiredApprovals;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function proposeTransaction(address _to, uint _value, bytes memory _data) external onlyOwner {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            approvalCount: 0
        }));

        emit TransactionProposed(transactions.length - 1, _to, _value, _data);
    }

    function approveTransaction(uint _txId) external onlyOwner txExists(_txId) notApproved(_txId) notExecuted(_txId) {
        approvals[_txId][msg.sender] = true;
        transactions[_txId].approvalCount += 1;

        emit TransactionApproved(msg.sender, _txId);
    }

    function executeTransaction(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        Transaction storage transaction = transactions[_txId];
        require(transaction.approvalCount >= requiredApprovals, "Not enough approvals");

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit TransactionExecuted(_txId);
    }

    function revokeApproval(uint _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(approvals[_txId][msg.sender], "Transaction not approved");

        approvals[_txId][msg.sender] = false;
        transactions[_txId].approvalCount -= 1;

        emit TransactionRevoked(msg.sender, _txId);
    }

    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }
}

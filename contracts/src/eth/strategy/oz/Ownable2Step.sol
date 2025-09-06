// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract Ownable2Step {
    address private _owner;
    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "owner=0");
        _owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "NOT_OWNER");
        _;
    }

    function owner() public view returns (address) { return _owner; }
    function pendingOwner() public view returns (address) { return _pendingOwner; }

    function _transferOwnership(address newOwner) internal {
        _owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "owner=0");
        address prev = _owner;
        _owner = newOwner;
        _pendingOwner = address(0);
        // Emit both events for compatibility
        emit OwnershipTransferStarted(prev, newOwner);
        emit OwnershipTransferred(prev, newOwner);
    }

    function acceptOwnership() public {
        require(msg.sender == _pendingOwner, "NOT_PENDING");
        _owner = _pendingOwner;
        _pendingOwner = address(0);
        emit OwnershipTransferred(_owner, msg.sender);
    }
}

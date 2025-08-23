// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

abstract contract Pausable {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    modifier whenNotPaused() {
        require(!_paused, "PAUSED");
        _;
    }

    modifier whenPaused() {
        require(_paused, "NOT_PAUSED");
        _;
    }

    function paused() public view returns (bool) { return _paused; }

    function _pause() internal whenNotPaused { _paused = true; emit Paused(msg.sender); }
    function _unpause() internal whenPaused { _paused = false; emit Unpaused(msg.sender); }
}

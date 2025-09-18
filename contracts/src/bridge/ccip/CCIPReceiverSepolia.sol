// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CCIPReceiverSepolia is CCIPReceiver {
    address public immutable usdtSepolia;
    address public immutable strategySink;

    // Events
    event CCIPReceived(
        bytes32 indexed messageId,
        uint64 indexed srcSelector,
        address indexed sink,
        uint256 amount,
        bool tokenTransfer
    );

    constructor(
        address _router,
        address _usdtSepolia,
        address _strategySink
    ) CCIPReceiver(_router) {
        usdtSepolia = _usdtSepolia;
        strategySink = _strategySink;
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        bytes32 messageId = message.messageId;
        uint64 sourceChainSelector = message.sourceChainSelector;
        bytes memory data = message.data;
        Client.EVMTokenAmount[] memory tokens = message.destTokenAmounts;

        if (tokens.length == 0) {
            // Message-only transfer (mint mode)
            (address srcVault, address usdtSrc, uint256 amt) = abi.decode(
                data,
                (address, address, uint256)
            );

            // Mint USDT to strategy sink
            (bool ok, ) = usdtSepolia.call(
                abi.encodeWithSignature("mint(address,uint256)", strategySink, amt)
            );
            require(ok, "mint fail");

            emit CCIPReceived(messageId, sourceChainSelector, strategySink, amt, false);
        } else {
            // Token transfer mode
            uint256 total = 0;
            for (uint i = 0; i < tokens.length; i++) {
                IERC20(tokens[i].token).transfer(strategySink, tokens[i].amount);
                total += tokens[i].amount;
            }

            emit CCIPReceived(messageId, sourceChainSelector, strategySink, total, true);
        }
    }
}
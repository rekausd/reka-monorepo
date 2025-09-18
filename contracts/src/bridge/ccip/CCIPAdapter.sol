// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CCIPAdapter {
    IRouterClient public immutable router;
    IERC20 public immutable usdt;

    // Events
    event CCIPSend(
        bytes32 indexed messageId,
        uint64 indexed dstSelector,
        address indexed to,
        uint256 amount,
        address feeToken,
        uint256 gasLimit
    );

    constructor(address _router, address _usdt) {
        router = IRouterClient(_router);
        usdt = IERC20(_usdt);
    }

    function bridgeUSDT(
        uint64 destChainSelector,
        address destReceiver,
        uint256 amount,
        address feeToken,
        uint256 gasLimitHint
    ) external payable returns (bytes32 msgId) {
        // Transfer USDT from sender to this contract
        usdt.transferFrom(msg.sender, address(this), amount);

        // Approve router to spend tokens if using token for fees
        if (feeToken != address(0)) {
            IERC20(feeToken).approve(address(router), type(uint256).max);
        }

        // Prepare CCIP message
        Client.EVM2AnyMessage memory m = Client.EVM2AnyMessage({
            receiver: abi.encode(destReceiver),
            data: abi.encode(address(this), address(usdt), amount),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: gasLimitHint})
            ),
            feeToken: feeToken
        });

        // Send via CCIP
        msgId = router.ccipSend{value: msg.value}(destChainSelector, m);

        // Emit event
        emit CCIPSend(msgId, destChainSelector, destReceiver, amount, feeToken, gasLimitHint);

        return msgId;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RouterMock is IRouterClient {
    uint256 private fees;
    bytes32 private nextMessageId;

    function getFee(
        uint64 destinationChainSelector,
        Client.EVM2AnyMessage memory message
    ) external view returns (uint256) {
        return fees;
    }

    function ccipSend(
        uint64 destinationChainSelector,
        Client.EVM2AnyMessage memory message
    ) external payable returns (bytes32) {
        require(
            IERC20(message.feeToken).allowance(msg.sender, address(this)) >= fees,
            "Insufficient allowance"
        );

        require(
            IERC20(message.feeToken).transferFrom(msg.sender, address(this), fees),
            "Fee transfer failed"
        );

        return nextMessageId;
    }

    function isChainSupported(uint64 chainSelector) external view returns (bool) {
        return true; 
    }

    function setFees(uint256 _fees) external {
        fees = _fees;
    }

    function setNextMessageId(bytes32 _nextMessageId) external {
        nextMessageId = _nextMessageId;
    }
}
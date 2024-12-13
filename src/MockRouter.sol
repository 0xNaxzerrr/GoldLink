// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRouterClient} from "@chainlink/contracts/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts/ccip/libraries/Client.sol";

contract MockRouter is IRouterClient {
    function ccipSend(
        uint64 destinationChainSelector,
        Client.EVM2AnyMessage calldata message
    ) external payable override returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    destinationChainSelector,
                    message.receiver,
                    message.data,
                    message.tokenAmounts.length
                )
            );
    }

    function getFee(
        uint64,
        Client.EVM2AnyMessage memory
    ) external pure override returns (uint256 fee) {
        return 0.01 ether;
    }

    function isChainSupported(
        uint64
    ) external pure override returns (bool supported) {
        return true;
    }
    receive() external payable {}
}

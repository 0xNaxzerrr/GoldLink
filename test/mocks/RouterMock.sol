// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/ccip/interfaces/IRouterClient.sol";

contract RouterMock is IRouterClient {
    function isChainSupported(uint64) external pure returns (bool) {
        return true;
    }
    function ccipSend(
        uint64,
        Client.EVM2AnyMessage memory
    ) external payable returns (bytes32) {
        return bytes32(0);
    }

    function getFee(
        uint64,
        Client.EVM2AnyMessage memory
    ) external pure returns (uint256) {
        return 0.01 ether;
    }
}
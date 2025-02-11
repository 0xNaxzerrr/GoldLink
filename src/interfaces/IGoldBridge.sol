// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/ccip/libraries/Client.sol";

interface IGoldBridge {
    error UnauthorizedRouter();
    error InvalidRecipient();
    error InvalidAmount();
    error InsufficientBalance();
    error InsufficientFees();
    error TransferFailed();
    event RemoteContractSet(bytes remoteContract);
    event DestinationChainSet(uint64 chainId);
    
    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainId,
        address recipient,
        uint256 amount
    );
    event TokensBridged(address indexed recipient, uint256 amount);

    function bridgeOut(address recipient, uint256 amount) external;
    function setRemoteContract(bytes memory _remoteContract) external;
    function setDestinationChainId(uint64 _chainId) external;
}
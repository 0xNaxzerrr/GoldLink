// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGoldBridgeBSC {
    error InvalidSourceChain();
    error InvalidSourceAddress(); 
    error InvalidRecipient();
    error InvalidAmount();
    error InsufficientBalance();
    error InsufficientFees();
    error TransferFailed();
    error UnauthorizedRouter(address sender);

    event MessageSent(bytes32 indexed messageId, uint64 indexed destinationChainId, address recipient, uint256 amount);
    event TokensBridged(address indexed recipient, uint256 amount);
    event RemoteContractSet(bytes remoteContract);
    event SepoliaChainIdSet(uint64 chainId);
    event AuthorizedSourceAddressSet(address sourceAddress);

    function bridgeBack(address recipient, uint256 amount) external;
    function setAuthorizedSourceAddress(address _sourceAddress) external;
    function setRemoteContract(bytes memory _remoteContract) external;
    function setSepoliaChainId(uint64 _sepoliaChainId) external;
}
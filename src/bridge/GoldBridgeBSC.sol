// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/ccip/applications/CCIPReceiver.sol";
import "@chainlink/contracts/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";
import "../tokens/GoldTokenBSC.sol";
import "../interfaces/IGoldBridgeBSC.sol";

/// @title Gold Bridge BSC
/// @notice Bridge pour transferts cross-chain côté BSC
/// @dev Utilise Chainlink CCIP et pattern UUPS
contract GoldBridgeBSC is IGoldBridgeBSC, CCIPReceiver, OwnableUpgradeable, UUPSUpgradeable {
    GoldTokenBSC public immutable goldToken;
    bytes public remoteContractOnSepoliaChain;
    uint64 public sepoliaChainId;
    address public authorizedSourceAddress;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _router,
        address _goldToken,
        bytes memory _remoteContract,
        uint64 _sepoliaChainId
    ) CCIPReceiver(_router) {
        if (_goldToken == address(0)) revert InvalidRecipient();
        goldToken = GoldTokenBSC(_goldToken);
        remoteContractOnSepoliaChain = _remoteContract;
        sepoliaChainId = _sepoliaChainId;
    }

    /// @notice Initialise le contrat upgradeable
    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        if (message.sourceChainSelector != sepoliaChainId) 
            revert InvalidSourceChain();

        if (abi.decode(message.sender, (address)) != authorizedSourceAddress)
            revert InvalidSourceAddress();

        (address recipient, uint256 amount) = abi.decode(message.data, (address, uint256));
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        goldToken.bridgeMint(recipient, amount);
        emit TokensBridged(recipient, amount);
    }

    function bridgeBack(address recipient, uint256 amount) external override {
        if (goldToken.balanceOf(msg.sender) < amount) 
            revert InsufficientBalance();

        goldToken.burnFrom(msg.sender, amount);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);
        bytes memory extraArgs = Client._argsToBytes(
            Client.EVMExtraArgsV1({gasLimit: 200000})
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: remoteContractOnSepoliaChain,
            data: abi.encode(recipient, amount),
            tokenAmounts: tokenAmounts,
            extraArgs: extraArgs,
            feeToken: address(0)
        });

        IRouterClient router = IRouterClient(getRouter());
        uint256 fees = router.getFee(sepoliaChainId, message);

        bytes32 messageId = router.ccipSend{value: fees}(
            sepoliaChainId,
            message
        );

        emit MessageSent(messageId, sepoliaChainId, recipient, amount);
    }

    function setAuthorizedSourceAddress(address _sourceAddress) external override onlyOwner {
        if (_sourceAddress == address(0)) revert InvalidRecipient();
        authorizedSourceAddress = _sourceAddress;
    }

    function setRemoteContract(bytes memory _remoteContract) external override onlyOwner {
        remoteContractOnSepoliaChain = _remoteContract;
    }

    function setSepoliaChainId(uint64 _sepoliaChainId) external override onlyOwner {
        sepoliaChainId = _sepoliaChainId;
    }

    function withdrawFunds(address payable recipient, uint256 amount) external override onlyOwner {
        if (address(this).balance < amount) revert InsufficientBalance();
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /// @notice Autorise une mise à niveau
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    receive() external payable {}
}
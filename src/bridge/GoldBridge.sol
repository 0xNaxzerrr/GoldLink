// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";
import "../tokens/GoldToken.sol";
import "../interfaces/IGoldBridge.sol";

/// @title Gold Bridge pour les transferts cross-chain
/// @notice Permet le bridging des tokens Gold entre Ethereum et BSC
/// @dev Utilise Chainlink CCIP et le pattern UUPS
contract GoldBridge is IGoldBridge, OwnableUpgradeable, UUPSUpgradeable, IAny2EVMMessageReceiver {
    IRouterClient public immutable router;
    GoldToken public immutable goldToken;
    bytes public remoteContractOnDestinationChain;
    uint64 public destinationChainId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _routerAddress,
        address _goldToken,
        bytes memory _remoteContract,
        uint64 _destinationChainId
    ) {
        if (_routerAddress == address(0) || _goldToken == address(0)) 
            revert InvalidRecipient();
        router = IRouterClient(_routerAddress);
        goldToken = GoldToken(_goldToken);
        remoteContractOnDestinationChain = _remoteContract;
        destinationChainId = _destinationChainId;
    }

    /// @notice Initialise le contrat upgradeable
    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /// @notice Bridge des tokens vers BSC
    function bridgeOut(address recipient, uint256 amount) external override {
        if (goldToken.balanceOf(msg.sender) < amount) 
            revert InsufficientBalance();

        goldToken.burnFrom(msg.sender, amount);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);
        bytes memory extraArgs = Client._argsToBytes(
            Client.EVMExtraArgsV1({gasLimit: 200000})
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: remoteContractOnDestinationChain,
            data: abi.encode(recipient, amount),
            tokenAmounts: tokenAmounts,
            extraArgs: extraArgs,
            feeToken: address(0)
        });

        uint256 fees = router.getFee(destinationChainId, message);
        if (address(this).balance < fees) 
            revert InsufficientFees();

        bytes32 messageId = router.ccipSend{value: fees}(
            destinationChainId,
            message
        );
        emit MessageSent(messageId, destinationChainId, recipient, amount);
    }

    /// @notice Reçoit les messages CCIP
    function ccipReceive(Client.Any2EVMMessage memory ccipMessage) external override(IAny2EVMMessageReceiver, IGoldBridge) {
        if (msg.sender != address(router)) revert UnauthorizedRouter();

        (address recipient, uint256 amount) = abi.decode(
            ccipMessage.data,
            (address, uint256)
        );
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        goldToken.bridgeMint(recipient, amount);
        emit TokensBridged(recipient, amount);
    }

    /// @notice Définit l'adresse du contrat distant
    function setRemoteContract(bytes memory _remoteContract) external onlyOwner {
        remoteContractOnDestinationChain = _remoteContract;
    }

    /// @notice Définit l'ID de la chaîne de destination
    function setDestinationChainId(uint64 _chainId) external onlyOwner {
        destinationChainId = _chainId;
    }

    /// @notice Dépose des fonds pour les frais CCIP
    function depositFunds() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    /// @notice Retire les fonds excédentaires
    function withdrawExcessFunds(address payable _to, uint256 _amount) external onlyOwner {
        if (_amount > address(this).balance) revert InsufficientBalance();
        (bool success, ) = _to.call{value: _amount}("");
        if (!success) revert TransferFailed();
    }

    /// @notice Autorise une mise à niveau
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }
}
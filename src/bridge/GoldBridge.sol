// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";
import "../tokens/GoldToken.sol";
import "../interfaces/IGoldBridge.sol";
import "@chainlink/contracts/shared/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/ccip/applications/CCIPReceiver.sol";

/**
 * @title GoldBridge
 * @notice Permet de bridge des tokens GOLD vers une autre chaîne via Chainlink CCIP.
 * @dev Ce contrat est upgradeable (proxy UUPS) et hérite de CCIPReceiver pour gérer la réception des messages.
 */
contract GoldBridge is
    IGoldBridge,
    OwnableUpgradeable,
    UUPSUpgradeable,
    CCIPReceiver
{
    /// @notice Instance du routeur Chainlink CCIP
    IRouterClient public immutable router;

    /// @notice Instance du token GOLD utilisé pour le bridge
    GoldToken public immutable goldToken;

    /// @notice Instance du token LINK utilisé pour payer les frais de transaction CCIP
    LinkTokenInterface public immutable linkToken;

    /// @notice Adresse encodée du contrat distant sur la chaîne de destination
    bytes public remoteContractOnDestinationChain;

    /// @notice Identifiant de la chaîne de destination pour le bridge
    uint64 public destinationChainId;

    /**
     * @notice Constructeur du contrat.
     * @dev Initialise les paramètres immutables du bridge et la configuration de base.
     * @param _routerAddress Adresse du routeur Chainlink CCIP.
     * @param _goldToken Adresse du token GOLD.
     * @param _linkToken Adresse du token LINK.
     * @param _remoteContract Encodage de l'adresse du contrat distant.
     * @param _destinationChainId Identifiant de la chaîne de destination.
     *
     * Requirements:
     * - `_routerAddress`, `_goldToken` et `_linkToken` ne doivent pas être l'adresse zéro.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _routerAddress,
        address _goldToken,
        address _linkToken,
        bytes memory _remoteContract,
        uint64 _destinationChainId
    ) CCIPReceiver(_routerAddress) {
        if (_routerAddress == address(0) || _goldToken == address(0) || _linkToken == address(0)) {
            revert InvalidRecipient();
        }
        router = IRouterClient(_routerAddress);
        goldToken = GoldToken(_goldToken);
        linkToken = LinkTokenInterface(_linkToken);

        remoteContractOnDestinationChain = _remoteContract;
        destinationChainId = _destinationChainId;
    }

    /**
     * @notice Initialise le contrat upgradeable.
     * @dev Doit être appelé une seule fois pour initialiser le contrat après déploiement.
     */
    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /**
     * @notice Bridge des tokens GOLD vers la chaîne de destination.
     * @dev L'expéditeur doit avoir suffisamment de tokens GOLD et de LINK pour payer les frais.
     * Le montant de tokens GOLD est brûlé sur la chaîne source et un message est envoyé via CCIP.
     * @param recipient Adresse du destinataire sur la chaîne de destination.
     * @param amount Quantité de tokens GOLD à bridge.
     *
     * Requirements:
     * - Le solde de GOLD du msg.sender doit être au moins égal à `amount`.
     * - Le msg.sender doit détenir suffisamment de LINK pour couvrir les frais de transaction.
     *
     * Emits a {MessageSent} event.
     */
    function bridgeOut(address recipient, uint256 amount) external override {
        if (goldToken.balanceOf(msg.sender) < amount) {
            revert InsufficientBalance();
        }

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);
        bytes memory extraArgs = Client._argsToBytes(
            Client.EVMExtraArgsV1({gasLimit: 200000})
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: remoteContractOnDestinationChain,
            data: abi.encode(recipient, amount),
            tokenAmounts: tokenAmounts,
            extraArgs: extraArgs,
            feeToken: address(linkToken)
        });

        uint256 fees = router.getFee(destinationChainId, message);

        if (linkToken.balanceOf(msg.sender) < fees) {
            revert InsufficientFees();
        }

        if (!linkToken.transferFrom(msg.sender, address(this), fees)) {
            revert TransferFailed();
        }

        goldToken.burnFrom(msg.sender, amount);

        linkToken.approve(address(router), fees);
        bytes32 messageId = router.ccipSend(destinationChainId, message);

        emit MessageSent(messageId, destinationChainId, recipient, amount);
    }

    /**
     * @notice Fonction interne appelée pour recevoir les messages CCIP.
     * @dev Seul le routeur CCIP est autorisé à appeler cette fonction.
     * @param message Message reçu via CCIP contenant l'adresse du destinataire et le montant.
     *
     * Requirements:
     * - L'expéditeur du message doit être le routeur CCIP.
     * - Le message doit contenir une adresse de destinataire valide et un montant non nul.
     *
     * Emits a {TokensBridged} event.
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        if (msg.sender != address(router)) revert UnauthorizedRouter();

        (address recipient, uint256 amount) = abi.decode(
            message.data,
            (address, uint256)
        );
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        goldToken.bridgeMint(recipient, amount);
        emit TokensBridged(recipient, amount);
    }

    /**
     * @notice Définit l'adresse du contrat distant sur la chaîne de destination.
     * @dev Cette fonction ne peut être appelée que par le propriétaire du contrat.
     * @param _remoteContract Nouvelle adresse distante encodée.
     *
     * Emits a {RemoteContractSet} event.
     */
    function setRemoteContract(bytes memory _remoteContract) external onlyOwner {
        remoteContractOnDestinationChain = _remoteContract;
        emit RemoteContractSet(_remoteContract);
    }

    /**
     * @notice Définit l'identifiant de la chaîne de destination pour le bridge.
     * @dev Cette fonction ne peut être appelée que par le propriétaire du contrat.
     * @param _chainId Nouvel identifiant de la chaîne de destination.
     *
     * Emits a {DestinationChainSet} event.
     */
    function setDestinationChainId(uint64 _chainId) external onlyOwner {
        destinationChainId = _chainId;
        emit DestinationChainSet(_chainId);
    }

    /**
     * @notice Autorise la mise à niveau du contrat.
     * @dev Seul le propriétaire peut autoriser une mise à niveau vers une nouvelle implémentation.
     * @param newImplementation Adresse du nouveau contrat d'implémentation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

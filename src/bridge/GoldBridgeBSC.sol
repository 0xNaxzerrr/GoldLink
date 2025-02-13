// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/ccip/applications/CCIPReceiver.sol";
import "@chainlink/contracts/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";
import "@chainlink/contracts/shared/interfaces/LinkTokenInterface.sol"; 
import "../tokens/GoldTokenBSC.sol";
import "../interfaces/IGoldBridgeBSC.sol";

/**
 * @title GoldBridgeBSC
 * @notice Permet de gérer les transferts cross-chain côté BSC pour le token GOLD.
 * @dev Utilise Chainlink CCIP pour la communication inter-chaînes, le paiement en LINK et le pattern UUPS pour la mise à niveau.
 */
contract GoldBridgeBSC is IGoldBridgeBSC, CCIPReceiver, OwnableUpgradeable, UUPSUpgradeable {
    /// @notice Instance du token GOLD sur BSC
    GoldTokenBSC public immutable goldToken;

    /// @notice Instance du token LINK utilisé pour payer les frais de CCIP
    LinkTokenInterface public immutable linkToken;

    /// @notice Adresse encodée du contrat distant sur la chaîne Sepolia
    bytes public remoteContractOnSepoliaChain;

    /// @notice Identifiant de la chaîne Sepolia
    uint64 public sepoliaChainId;

    /// @notice Adresse autorisée sur Sepolia (source des messages)
    address public authorizedSourceAddress;

    /**
     * @notice Constructeur du contrat.
     * @dev Initialise les variables immutables et la configuration de base du bridge.
     * @param _router Adresse du routeur CCIP.
     * @param _goldToken Adresse du token GOLD sur BSC.
     * @param _linkToken Adresse du token LINK.
     * @param _remoteContract Encodage de l'adresse du contrat distant sur Sepolia.
     * @param _sepoliaChainId Identifiant de la chaîne Sepolia.
     *
     * Requirements:
     * - `_goldToken` et `_linkToken` ne doivent pas être l'adresse zéro.
     *
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(
        address _router,
        address _goldToken,
        address _linkToken,
        bytes memory _remoteContract,
        uint64 _sepoliaChainId
    ) CCIPReceiver(_router) {
        if (_goldToken == address(0) || _linkToken == address(0)) {
            revert InvalidRecipient();
        }
        goldToken = GoldTokenBSC(_goldToken);
        linkToken = LinkTokenInterface(_linkToken);
        remoteContractOnSepoliaChain = _remoteContract;
        sepoliaChainId = _sepoliaChainId;
    }

    /**
     * @notice Initialise le contrat upgradeable.
     * @dev Doit être appelé une seule fois après le déploiement pour initialiser le contrat.
     */
    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /**
     * @notice Réceptionne les messages CCIP en provenance de Sepolia.
     * @dev Seul le routeur CCIP peut appeler cette fonction. 
     *      Le message doit provenir de la chaîne Sepolia et de l'adresse source autorisée.
     * @param message Le message reçu via CCIP contenant les données du transfert.
     *
     * Requirements:
     * - `message.sourceChainSelector` doit être égal à `sepoliaChainId`.
     * - `abi.decode(message.sender, (address))` doit correspondre à `authorizedSourceAddress`.
     * - Le `recipient` extrait de `message.data` ne doit pas être l'adresse zéro.
     * - Le `amount` extrait de `message.data` doit être supérieur à zéro.
     *
     * Emits a {TokensBridged} event.
     */
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        // Vérifie que le message provient bien de la chaîne Sepolia
        if (message.sourceChainSelector != sepoliaChainId) {
            revert InvalidSourceChain();
        }
        // Vérifie que l'émetteur du message est bien l'adresse autorisée
        if (abi.decode(message.sender, (address)) != authorizedSourceAddress) {
            revert InvalidSourceAddress();
        }

        (address recipient, uint256 amount) = abi.decode(message.data, (address, uint256));
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        goldToken.bridgeMint(recipient, amount);
        emit TokensBridged(recipient, amount);
    }

    /**
     * @notice Permet de renvoyer des tokens de BSC vers Sepolia (bridgeBack).
     * @dev Le frais de transaction est payé en LINK. Les tokens GOLD sont brûlés sur BSC.
     * @param recipient Adresse du destinataire sur Sepolia.
     * @param amount Quantité de tokens à bridger.
     *
     * Requirements:
     * - Le solde de tokens GOLD de `msg.sender` doit être au moins égal à `amount`.
     * - `msg.sender` doit disposer d'une quantité suffisante de LINK pour payer les frais de CCIP.
     *
     * Emits a {MessageSent} event.
     */
    function bridgeBack(address recipient, uint256 amount) external override {
        // Vérifie que l'utilisateur dispose d'un solde suffisant en GOLD sur BSC
        if (goldToken.balanceOf(msg.sender) < amount) {
            revert InsufficientBalance();
        }

        // Brûle les tokens GOLD de l'utilisateur
        goldToken.burnFrom(msg.sender, amount);

        // Prépare le message CCIP
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](0);
        bytes memory extraArgs = Client._argsToBytes(
            Client.EVMExtraArgsV1({gasLimit: 200_000})
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: remoteContractOnSepoliaChain,
            data: abi.encode(recipient, amount),
            tokenAmounts: tokenAmounts,
            extraArgs: extraArgs,
            feeToken: address(linkToken)
        });

        IRouterClient router_ = IRouterClient(getRouter());
        uint256 fees = router_.getFee(sepoliaChainId, message);

        // Vérifie que l'utilisateur dispose d'assez de LINK pour couvrir les frais
        if (linkToken.balanceOf(msg.sender) < fees) {
            revert InsufficientFees();
        }

        if (!linkToken.transferFrom(msg.sender, address(this), fees)) {
            revert TransferFailed();
        }

        linkToken.approve(address(router_), fees);

        bytes32 messageId = router_.ccipSend(sepoliaChainId, message);

        emit MessageSent(messageId, sepoliaChainId, recipient, amount);
    }

    // --------------------------- Config ---------------------------

    /**
     * @notice Définit l'adresse source autorisée provenant de Sepolia.
     * @dev Seul le propriétaire peut appeler cette fonction.
     * @param _sourceAddress Nouvelle adresse source autorisée.
     *
     * Requirements:
     * - `_sourceAddress` ne doit pas être l'adresse zéro.
     *
     * Emits a {AuthorizedSourceAddressSet} event.
     */
    function setAuthorizedSourceAddress(address _sourceAddress) external override onlyOwner {
        if (_sourceAddress == address(0)) revert InvalidRecipient();
        authorizedSourceAddress = _sourceAddress;
        emit AuthorizedSourceAddressSet(_sourceAddress);
    }

    /**
     * @notice Définit l'adresse encodée du contrat distant sur Sepolia.
     * @dev Seul le propriétaire peut appeler cette fonction.
     * @param _remoteContract Nouvelle adresse distante encodée.
     *
     * Emits a {RemoteContractSet} event.
     */
    function setRemoteContract(bytes memory _remoteContract) external override onlyOwner {
        remoteContractOnSepoliaChain = _remoteContract;
        emit RemoteContractSet(_remoteContract);
    }

    /**
     * @notice Définit l'identifiant de la chaîne Sepolia.
     * @dev Seul le propriétaire peut appeler cette fonction.
     * @param _sepoliaChainId Nouvel identifiant de la chaîne Sepolia.
     *
     * Emits a {SepoliaChainIdSet} event.
     */
    function setSepoliaChainId(uint64 _sepoliaChainId) external override onlyOwner {
        sepoliaChainId = _sepoliaChainId;
        emit SepoliaChainIdSet(_sepoliaChainId);
    }

    /**
     * @notice Autorise la mise à niveau du contrat.
     * @dev Seul le propriétaire peut autoriser une mise à niveau.
     * @param newImplementation Adresse du nouveau contrat d'implémentation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

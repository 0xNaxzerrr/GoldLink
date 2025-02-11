// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/ccip/applications/CCIPReceiver.sol";
import "@chainlink/contracts/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";
import "@chainlink/contracts/shared/interfaces/LinkTokenInterface.sol"; // <-- on importe l'interface LINK
import "../tokens/GoldTokenBSC.sol";
import "../interfaces/IGoldBridgeBSC.sol";

/// @title Gold Bridge BSC
/// @notice Bridge pour transferts cross-chain côté BSC
/// @dev Utilise Chainlink CCIP et pattern UUPS + paiement en LINK
contract GoldBridgeBSC is IGoldBridgeBSC, CCIPReceiver, OwnableUpgradeable, UUPSUpgradeable {
    GoldTokenBSC public immutable goldToken;
    LinkTokenInterface public immutable linkToken; // <-- on stocke l'adresse du token LINK

    bytes public remoteContractOnSepoliaChain;
    uint64 public sepoliaChainId;
    address public authorizedSourceAddress;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _router,
        address _goldToken,
        address _linkToken,                // <-- nouveau paramètre pour l'adresse LINK sur BSC
        bytes memory _remoteContract,
        uint64 _sepoliaChainId
    ) CCIPReceiver(_router) {
        if (_goldToken == address(0) || _linkToken == address(0)) {
            revert InvalidRecipient();
        }
        goldToken = GoldTokenBSC(_goldToken);
        linkToken = LinkTokenInterface(_linkToken); // on cast l'adresse en interface LINK
        remoteContractOnSepoliaChain = _remoteContract;
        sepoliaChainId = _sepoliaChainId;
    }

    /// @notice Initialise le contrat upgradeable
    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /// @dev Méthode appelée automatiquement par le Router CCIP lorsqu'un message arrive.
    ///      Seule l'adresse du router CCIP peut invoquer ccipReceive(...).
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        // Vérifie qu'on vient de Sepolia
        if (message.sourceChainSelector != sepoliaChainId) {
            revert InvalidSourceChain();
        }

        // Vérifie que le "sender" correspond bien à la passerelle Sepolia autorisée
        if (abi.decode(message.sender, (address)) != authorizedSourceAddress) {
            revert InvalidSourceAddress();
        }

        (address recipient, uint256 amount) = abi.decode(message.data, (address, uint256));
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        // Mint sur le token BSC
        goldToken.bridgeMint(recipient, amount);
        emit TokensBridged(recipient, amount);
    }

    /// @notice Permet de "re-partir" de BSC vers Sepolia (le "bridgeBack")
    /// @dev Paiement des frais en LINK
    function bridgeBack(address recipient, uint256 amount) external override {
        // 1) Vérifie qu'on a assez de tokens BSC à burner
        if (goldToken.balanceOf(msg.sender) < amount) {
            revert InsufficientBalance();
        }

        // 2) On burnFrom pour retirer les tokens à l'utilisateur
        goldToken.burnFrom(msg.sender, amount);

        // 3) On construit le message CCIP
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

        // 4) Récupère le montant de fees
        IRouterClient router_ = IRouterClient(getRouter());
        uint256 fees = router_.getFee(sepoliaChainId, message);

        // 5) Vérifie que l'utilisateur a assez de LINK
        if (linkToken.balanceOf(msg.sender) < fees) {
            revert InsufficientFees();
        }

        // 6) Transfert les LINK de l'utilisateur vers le bridge
        if (!linkToken.transferFrom(msg.sender, address(this), fees)) {
            revert TransferFailed();
        }

        // 7) On approve le router pour qu'il prenne les fees en LINK
        linkToken.approve(address(router_), fees);

        // 8) On envoie le message
        bytes32 messageId = router_.ccipSend(sepoliaChainId, message);

        emit MessageSent(messageId, sepoliaChainId, recipient, amount);
    }

    // --------------------------- Configuration & Admin ---------------------------

    function setAuthorizedSourceAddress(address _sourceAddress) external override onlyOwner {
        if (_sourceAddress == address(0)) revert InvalidRecipient();
        authorizedSourceAddress = _sourceAddress;
        emit AuthorizedSourceAddressSet(_sourceAddress);
    }

    function setRemoteContract(bytes memory _remoteContract) external override onlyOwner {
        remoteContractOnSepoliaChain = _remoteContract;
        emit RemoteContractSet(_remoteContract);
    }

    function setSepoliaChainId(uint64 _sepoliaChainId) external override onlyOwner {
        sepoliaChainId = _sepoliaChainId;
        emit SepoliaChainIdSet(_sepoliaChainId);
    }
    /// @notice Autorise une mise à niveau
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}

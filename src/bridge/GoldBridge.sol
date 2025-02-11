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

contract GoldBridge is
    IGoldBridge,
    OwnableUpgradeable,
    UUPSUpgradeable,
    CCIPReceiver
{
    IRouterClient public immutable router;
    GoldToken public immutable goldToken;

    LinkTokenInterface public immutable linkToken;

    bytes public remoteContractOnDestinationChain;
    uint64 public destinationChainId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _routerAddress,
        address _goldToken,
        address _linkToken,
        bytes memory _remoteContract,
        uint64 _destinationChainId
    ) CCIPReceiver(_routerAddress){
        if (_routerAddress == address(0) || _goldToken == address(0) || _linkToken == address(0)) {
            revert InvalidRecipient();
        }
        router = IRouterClient(_routerAddress);
        goldToken = GoldToken(_goldToken);
        linkToken = LinkTokenInterface(_linkToken);

        remoteContractOnDestinationChain = _remoteContract;
        destinationChainId = _destinationChainId;
    }

    /// @notice Initialise le contrat upgradeable
    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /// @notice Bridge des tokens vers BSC
    /// @dev Paiement des frais en LINK, pas en msg.value
    function bridgeOut(address recipient, uint256 amount) external override {
        // 1. Vérifie le solde de tokens
        if (goldToken.balanceOf(msg.sender) < amount) {
            revert InsufficientBalance();
        }

        // 2. Prépare le message CCIP
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

        // 3. Calcule les frais LINK
        uint256 fees = router.getFee(destinationChainId, message);

        // 4. Vérifie que l'utilisateur a assez de LINK
        if (linkToken.balanceOf(msg.sender) < fees) {
            revert InsufficientFees();
        }

        // 5. Transfère les LINK de l'utilisateur au bridge
        if (!linkToken.transferFrom(msg.sender, address(this), fees)) {
            revert TransferFailed();
        }

        // 6. Brûle les tokens
        goldToken.burnFrom(msg.sender, amount);

        // 7. Envoie le message CCIP
        linkToken.approve(address(router), fees);
        bytes32 messageId = router.ccipSend(destinationChainId, message);

        emit MessageSent(messageId, destinationChainId, recipient, amount);
    }

    /// @notice Reçoit les messages CCIP
    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        // Vérifie que le sender est le router
        if (msg.sender != address(router)) revert UnauthorizedRouter();

        (address recipient, uint256 amount) = abi.decode(
            message.data,
            (address, uint256)
        );
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        // Mint sur le token
        goldToken.bridgeMint(recipient, amount);
        emit TokensBridged(recipient, amount);
    }

    /// @notice Définit l'adresse du contrat distant
    function setRemoteContract(bytes memory _remoteContract) external onlyOwner {
        remoteContractOnDestinationChain = _remoteContract;
        emit RemoteContractSet(_remoteContract);
    }

    /// @notice Définit l'ID de la chaîne de destination
    function setDestinationChainId(uint64 _chainId) external onlyOwner {
        destinationChainId = _chainId;
        emit DestinationChainSet(_chainId);
    }

    /// @notice Autorise une mise à niveau
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}

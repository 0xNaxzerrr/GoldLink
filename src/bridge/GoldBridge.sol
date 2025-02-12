// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";
import "../tokens/GoldToken.sol";
import "../interfaces/IGoldBridge.sol";
import "@chainlink/contracts/shared/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/ccip/applications/CCIPReceiver.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
contract GoldBridge is
    Initializable,
    IGoldBridge,
    CCIPReceiver,
    OwnableUpgradeable,
    UUPSUpgradeable
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
    ) CCIPReceiver(_routerAddress) {
        if (
            _routerAddress == address(0) ||
            _goldToken == address(0) ||
            _linkToken == address(0)
        ) {
            revert InvalidRecipient();
        }
        router = IRouterClient(_routerAddress);
        goldToken = GoldToken(_goldToken);
        linkToken = LinkTokenInterface(_linkToken);

        remoteContractOnDestinationChain = _remoteContract;
        destinationChainId = _destinationChainId;
    }

    function initialize() external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function bridgeOut(address recipient, uint256 amount) external override {
        if (goldToken.balanceOf(msg.sender) < amount) {
            revert InsufficientBalance();
        }

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](0);
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

    function ccipReceive(
        Client.Any2EVMMessage calldata message
    ) external override(CCIPReceiver, IGoldBridge) {
        if (msg.sender != address(router))
            revert UnauthorizedRouter(msg.sender);
        _ccipReceive(message);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        (address recipient, uint256 amount) = abi.decode(
            message.data,
            (address, uint256)
        );
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        goldToken.bridgeMint(recipient, amount);
        emit TokensBridged(recipient, amount);
    }

    function setRemoteContract(
        bytes memory _remoteContract
    ) external onlyOwner {
        remoteContractOnDestinationChain = _remoteContract;
        emit RemoteContractSet(_remoteContract);
    }

    function setDestinationChainId(uint64 _chainId) external onlyOwner {
        destinationChainId = _chainId;
        emit DestinationChainSet(_chainId);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function _msgSender() internal view override returns (address sender) {
        sender = super._msgSender();
        if (msg.sig == this.ccipReceive.selector && sender != address(router)) {
            revert UnauthorizedRouter(sender);
        }
    }
}

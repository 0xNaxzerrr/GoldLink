// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/ccip/applications/CCIPReceiver.sol";
import "@chainlink/contracts/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";
import "./GoldTokenBSC.sol";
import {IAny2EVMMessageReceiver} from "@chainlink/contracts/ccip/interfaces/IAny2EVMMessageReceiver.sol";

contract GoldBridgeBSC is CCIPReceiver, Ownable {
    GoldTokenBSC public goldToken;
    bytes public remoteContractOnSepoliaChain;
    uint64 public sepoliaChainId;
    address public authorizedSourceAddress;

    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainId,
        address recipient,
        uint256 amount
    );

    event TokensBridged(address indexed recipient, uint256 amount);

    constructor(
        address _router,
        address _goldToken,
        bytes memory _remoteContract,
        uint64 _sepoliaChainId
    ) CCIPReceiver(_router) Ownable(msg.sender) {
        goldToken = GoldTokenBSC(_goldToken);
        remoteContractOnSepoliaChain = _remoteContract;
        sepoliaChainId = _sepoliaChainId;
        authorizedSourceAddress = address(0);
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return 
            interfaceId == type(IAny2EVMMessageReceiver).interfaceId || 
            interfaceId == type(IERC165).interfaceId;
    } 
    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        require(
            message.sourceChainSelector == sepoliaChainId,
            "Invalid source chain"
        );

        require(
            abi.decode(message.sender, (address)) == authorizedSourceAddress,
            "Invalid source address"
        );

        (address recipient, uint256 amount) = abi.decode(
            message.data,
            (address, uint256)
        );
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");

        goldToken.bridgeMint(recipient, amount);

        emit TokensBridged(recipient, amount);
    }

    function bridgeBack(address recipient, uint256 amount) external {
        require(
            goldToken.balanceOf(msg.sender) >= amount,
            "Insufficient balance"
        );

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

    function setAuthorizedSourceAddress(address _sourceAddress) external onlyOwner {
        require(_sourceAddress != address(0), "Invalid address");
        authorizedSourceAddress = _sourceAddress;
    }

    function setRemoteContract(bytes memory _remoteContract) external onlyOwner {
        remoteContractOnSepoliaChain = _remoteContract;
    }

    function setSepoliaChainId(uint64 _sepoliaChainId) external onlyOwner {
        sepoliaChainId = _sepoliaChainId;
    }

    function withdrawFunds(address payable recipient, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
    }

    receive() external payable {}
}
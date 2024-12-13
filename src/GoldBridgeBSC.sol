// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";
import "./GoldTokenBSC.sol";

contract GoldBridgeBSC is Ownable, IAny2EVMMessageReceiver {
    IRouterClient public router;
    GoldTokenBSC public goldToken;
    bytes public remoteContractOnSepoliaChain;
    uint64 public sepoliaChainId;

    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainId,
        address recipient,
        uint256 amount
    );

    constructor(
        address _routerAddress,
        address _goldToken,
        bytes memory _remoteContract,
        uint64 _sepoliaChainId
    ) Ownable(msg.sender) {
        router = IRouterClient(_routerAddress);
        goldToken = GoldTokenBSC(_goldToken);
        remoteContractOnSepoliaChain = _remoteContract;
        sepoliaChainId = _sepoliaChainId;
    }

    function ccipReceive(
        Client.Any2EVMMessage memory ccipMessage
    ) external override {
        require(msg.sender == address(router), "Only router can call");
        require(
            ccipMessage.sourceChainSelector == sepoliaChainId,
            "Invalid source chain"
        );

        (address recipient, uint256 amount) = abi.decode(
            ccipMessage.data,
            (address, uint256)
        );
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");

        goldToken.bridgeMint(recipient, amount);

        emit TokensBridged(recipient, amount);
    }

    event TokensBridged(address indexed recipient, uint256 amount);

    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "Invalid router address");
        router = IRouterClient(_router);
    }

    function bridgeBack(address recipient, uint256 amount) external {
        require(
            goldToken.balanceOf(msg.sender) >= amount,
            "Insufficient balance"
        );

        goldToken.burnFrom(msg.sender, amount);

        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](0);
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

        uint256 fees = router.getFee(sepoliaChainId, message);

        bytes32 messageId = router.ccipSend{value: fees}(
            sepoliaChainId,
            message
        );

        emit MessageSent(messageId, sepoliaChainId, recipient, amount);
    }

    function setRemoteContract(
        bytes memory _remoteContract
    ) external onlyOwner {
        remoteContractOnSepoliaChain = _remoteContract;
    }

    function setSepoliaChainId(uint64 _sepoliaChainId) external onlyOwner {
        sepoliaChainId = _sepoliaChainId;
    }

    function withdrawFunds(
        address payable recipient,
        uint256 amount
    ) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./GoldToken.sol";
import "@chainlink/contracts/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";

contract GoldBridge is Ownable, IAny2EVMMessageReceiver {
    IRouterClient public router;
    GoldToken public goldToken;

    bytes public remoteContractOnDestinationChain;
    uint64 public destinationChainId;
    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainId,
        address recipient,
        uint256 amount
    );
    event FundsReceived(address sender, uint256 amount);

    constructor(
        address _routerAddress,
        address _goldToken,
        bytes memory _remoteContract,
        uint64 _destinationChainId
    ) Ownable(msg.sender) {
        router = IRouterClient(_routerAddress);
        goldToken = GoldToken(_goldToken);
        remoteContractOnDestinationChain = _remoteContract;
        destinationChainId = _destinationChainId;
    }

    function bridgeOut(address recipient, uint256 amount) external {
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
            receiver: remoteContractOnDestinationChain,
            data: abi.encode(recipient, amount),
            tokenAmounts: tokenAmounts,
            extraArgs: extraArgs,
            feeToken: address(0) 
        });

        uint256 fees = router.getFee(destinationChainId, message);
        require(
            address(this).balance >= fees,
            "Insufficient ETH for CCIP fees"
        );

        bytes32 messageId = router.ccipSend{value: fees}(
            destinationChainId,
            message
        );
        emit MessageSent(messageId, destinationChainId, recipient, amount);
    }

    function ccipReceive(
        Client.Any2EVMMessage memory ccipMessage
    ) external override {
        require(msg.sender == address(router), "Only router can call");

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

    function setRemoteContract(
        bytes memory _remoteContract
    ) external onlyOwner {
        remoteContractOnDestinationChain = _remoteContract;
    }

    function setDestinationChainId(uint64 _chainId) external onlyOwner {
        destinationChainId = _chainId;
    }

    function depositFunds() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    function withdrawExcessFunds(
        address payable _to,
        uint256 _amount
    ) external onlyOwner {
        require(_amount <= address(this).balance, "Insufficient balance");
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Transfer failed");
    }

    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }
}

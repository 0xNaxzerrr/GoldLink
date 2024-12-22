// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";
import "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

/**
 * @title GoldLottery
 * @notice A lottery contract funded by fees collected during mint/burn operations in the GoldToken contract.
 *         A lottery is triggered every 1000 tokens minted (1000e18 units), distributing the collected fees to a random participant.
 */
contract GoldLottery is VRFConsumerBaseV2Plus {
    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
    }

    uint256 public s_subscriptionId;
    bytes32 public keyHash;
    uint256[] public requestIds;
    uint256 public lastRequestId;
    uint32 public callbackGasLimit;
    uint16 public requestConfirmations;
    uint32 public numWords;
    bool public useNativePayment;

    uint256 public tokensMinted;
    uint256 public lotteryBalance;
    address public lastWinner;
    uint256 public lastPayout;
    address[] public participants;
    mapping(address => uint256) public chances;

    mapping(uint256 => RequestStatus) public s_requests;

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event LotteryEntered(address indexed participant, uint256 chances);
    event LotteryWinner(address indexed winner, uint256 amount);

    constructor(
        uint256 subscriptionId,
        address vrfCoordinatorAddress,
        address initialOwner
    ) VRFConsumerBaseV2Plus(vrfCoordinatorAddress) {
        transferOwnership(initialOwner);
        s_subscriptionId = subscriptionId;
        keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
        callbackGasLimit = 100000;
        requestConfirmations = 3;
        numWords = 1; 
        useNativePayment = true;
    }

    function setNativePayment(bool _useNativePayment) external onlyOwner {
        useNativePayment = _useNativePayment;
    }

    function enterLottery(address participant, uint256 amount) external {
        require(participant != address(0), "Invalid participant address");
        require(amount > 0, "Amount must be greater than 0");

        tokensMinted += amount;

        if (chances[participant] == 0) participants.push(participant);
        chances[participant] += amount;

        emit LotteryEntered(participant, amount);


        if (tokensMinted >= 1000e18) {
            drawLottery();
        }
    }

    function depositFees(uint256 amount) external payable {
        require(msg.value == amount, "Incorrect fee amount");
        lotteryBalance += amount;
    }

    function drawLottery() public returns (uint256 requestId) {
        require(participants.length > 0, "No participants in the lottery");
        require(lotteryBalance > 0, "No funds in the lottery");

        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: useNativePayment})
                )
            })
        );

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](numWords),
            exists: true,
            fulfilled: false
        });

        requestIds.push(requestId);
        lastRequestId = requestId;

        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        require(s_requests[requestId].exists, "Request does not exist");
        require(!s_requests[requestId].fulfilled, "Request already fulfilled");
        require(address(this).balance >= lotteryBalance, "Insufficient contract balance");

        uint256 totalChances;
        for (uint256 i = 0; i < participants.length; i++) {
            totalChances += chances[participants[i]];
        }

        uint256 randomChance = randomWords[0] % totalChances;
        uint256 cumulativeChances = 0;
        address winner;

        for (uint256 i = 0; i < participants.length; i++) {
            cumulativeChances += chances[participants[i]];
            if (randomChance < cumulativeChances) {
                winner = participants[i];
                break;
            }
        }

        (bool success, ) = payable(winner).call{value: lotteryBalance}("");
        require(success, "Transfer to winner failed");

        emit LotteryWinner(winner, lotteryBalance);
        emit RequestFulfilled(requestId, randomWords);

        lastWinner = winner;
        lastPayout = lotteryBalance;
        delete participants;
        tokensMinted = 0;
        lotteryBalance = 0;

        s_requests[requestId].fulfilled = true;
        s_requests[requestId].randomWords = randomWords;

        resetChances();
    }

    function withdrawFunds(uint256 amount) external onlyOwner {
        require(
            address(this).balance - lotteryBalance >= amount,
            "Insufficient funds"
        );
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    function resetChances() private {
        for (uint256 i = 0; i < participants.length; i++) {
            chances[participants[i]] = 0;
        }
    }

    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    function getChances(address participant) external view returns (uint256) {
        return chances[participant];
    }

    receive() external payable {
        lotteryBalance += msg.value;
    }
}

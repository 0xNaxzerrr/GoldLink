// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GoldLottery
 * @notice A lottery contract funded by fees collected during mint/burn operations in the GoldToken contract.
 *         A lottery is triggered every 1000 tokens minted (1000e18 units), distributing the collected fees to a random participant.
 */
contract GoldLottery is VRFConsumerBaseV2, Ownable {
    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
    }

    VRFCoordinatorV2Interface internal vrfCoordinator;

    uint64 public s_subscriptionId;
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
        uint64 subscriptionId,
        address vrfCoordinatorAddress,
        address initialOwner
    ) VRFConsumerBaseV2(vrfCoordinatorAddress) Ownable(initialOwner) {
        vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
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

        requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
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

        (bool success, ) = winner.call{value: lotteryBalance}("");
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
    }

    function withdrawFunds(uint256 amount) external onlyOwner {
        require(
            address(this).balance - lotteryBalance >= amount,
            "Insufficient funds"
        );
        payable(msg.sender).transfer(amount);
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

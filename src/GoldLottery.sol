// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {VRFConsumerBaseV2Plus} from "@chainlink/local/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/local/lib/chainlink-brownie-contracts/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";

/**
 * @title GoldLottery
 * @notice A lottery contract funded by fees collected during mint operations in the GoldToken contract.
 *         A lottery is triggered every 1000 tokens minted, distributing the collected fees to a random participant.
 *         Each token minted gives the user one chance to win.
 */
contract GoldLottery is VRFConsumerBaseV2Plus {
    // Struct to store request status
    struct RequestStatus {
        bool fulfilled; // Whether the request has been fulfilled
        bool exists; // Whether the request exists
        uint256[] randomWords; // Random words returned by Chainlink VRF
    }

    /// @dev Chainlink VRF variables
    uint256 public s_subscriptionId; // Subscription ID for Chainlink VRF
    bytes32 public keyHash; // Key hash for VRF
    uint256[] public requestIds; // List of request IDs
    uint256 public lastRequestId; // Last request ID
    uint32 public callbackGasLimit; // Gas limit for VRF callback
    uint16 public requestConfirmations; // Confirmations for VRF request
    uint32 public numWords; // Number of random words to request
    bool public useNativePayment; // Whether to use native payments for VRF

    /// @dev Lottery state variables
    uint256 public tokensMinted; // Total tokens minted since the last lottery
    uint256 public lotteryBalance; // Total balance of the lottery
    address public lastWinner; // Address of the last lottery winner
    uint256 public lastPayout; // Amount paid out in the last lottery
    address[] public participants; // List of participants in the current lottery
    mapping(address => uint256) public chances; // Number of chances per participant

    /// @dev Randomness request tracking
    mapping(uint256 => RequestStatus) public s_requests; // Map requestId to request status

    /// @dev Events
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event LotteryEntered(address indexed participant, uint256 chances);
    event LotteryWinner(address indexed winner, uint256 amount);

    /**
     * @notice Initializes the GoldLottery contract.
     * @param subscriptionId The Chainlink VRF subscription ID.
     */
    constructor(
        uint256 subscriptionId
    ) VRFConsumerBaseV2Plus(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B) {
        s_subscriptionId = subscriptionId;
        keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
        callbackGasLimit = 100000;
        requestConfirmations = 3;
        numWords = 2;
        useNativePayment = true;
    }

    /**
     * @notice Allows the owner to set whether to use native payments for VRF requests.
     * @param _useNativePayment Boolean to enable or disable native payments.
     */
    function setNativePayment(bool _useNativePayment) external onlyOwner {
        useNativePayment = _useNativePayment;
    }

    /**
     * @notice Adds a participant to the lottery and updates their chances.
     * @dev This function is called by the GoldToken contract after minting.
     * @param participant The address of the participant.
     * @param amount The number of tokens minted, used as the number of chances.
     */
    function enterLottery(address participant, uint256 amount) external {
        require(participant != address(0), "Invalid participant address");
        require(amount > 0, "Amount must be greater than 0");

        tokensMinted += amount;

        if (chances[participant] == 0) participants.push(participant);
        chances[participant] += amount;

        emit LotteryEntered(participant, amount);

        if (tokensMinted >= 1000) drawLottery();
    }

    /**
     * @notice Deposits fees into the lottery balance.
     * @param amount The amount of fees to deposit.
     */
    function depositFees(uint256 amount) external payable {
        require(msg.value == amount, "Incorrect fee amount");
        lotteryBalance += amount;
    }

    /**
     * @notice Triggers a Chainlink VRF request for randomness to select a lottery winner.
     * @return requestId The ID of the VRF request.
     */
    function drawLottery() internal returns (uint256 requestId) {
        require(participants.length > 0, "No participants in the lottery");
        require(lotteryBalance > 0, "No funds in the lottery");

        // Request random words from Chainlink VRF
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: 1,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: useNativePayment
                    })
                )
            })
        );

        // Initialize request status
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](numWords),
            exists: true,
            fulfilled: false
        });

        // Track the request ID
        requestIds.push(requestId);
        lastRequestId = requestId;

        emit RequestSent(requestId, numWords);
        return requestId;
    }

    /**
     * @notice Callback for Chainlink VRF to fulfill randomness and select a winner.
     * @param requestId The ID of the VRF request.
     * @param randomWords The random words provided by Chainlink VRF.
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        require(s_requests[requestId].exists, "Request does not exist");
        require(!s_requests[requestId].fulfilled, "Request already fulfilled");

        uint256 totalChances = 0;
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

    /**
     * @notice Withdraws excess funds not used for the lottery.
     * @param amount The amount to withdraw.
     */
    function withdrawFunds(uint256 amount) external onlyOwner {
        require(
            address(this).balance - lotteryBalance >= amount,
            "Insufficient funds"
        );
        payable(msg.sender).transfer(amount);
    }

    /**
     * @notice Returns the list of participants in the current lottery.
     * @return An array of participant addresses.
     */
    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    /**
     * @notice Returns the number of chances for a specific participant.
     * @param participant The address of the participant.
     * @return The number of chances the participant has.
     */
    function getChances(address participant) external view returns (uint256) {
        return chances[participant];
    }

    /**
     * @notice Fallback function to accept ETH and add it to the lottery balance.
     */
    receive() external payable {
        lotteryBalance += msg.value;
    }
}

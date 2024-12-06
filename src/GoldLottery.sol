// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@chainlink/local/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

/**
 * @title GoldLottery
 * @notice This contract manages a lottery funded by fees collected during mint operations in the GoldToken contract.
 * A lottery is triggered every 1000 tokens minted, and the fees are distributed to a random user who minted tokens.
 * Each token minted gives the user one chance to win.
 */
contract GoldLottery is VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface private immutable vrfCoordinator;

    uint64 public immutable subscriptionId; // Chainlink subscription ID
    bytes32 public immutable keyHash; // Chainlink VRF key hash
    uint32 public constant callbackGasLimit = 200000; // Gas limit for VRF callback
    uint16 public constant requestConfirmations = 3; // VRF confirmations

    uint256 public tokensMinted; // Total tokens minted since the last lottery
    uint256 public lotteryBalance; // Accumulated fees for the current lottery
    address[] public participants; // List of all participants
    mapping(address => uint256) public chances; // Mapping to store minting chances for each user

    address public lastWinner; // Address of the last winner
    uint256 public lastPayout; // Amount of the last lottery payout

    event LotteryEntered(address indexed participant, uint256 chances);
    event LotteryWinner(address indexed winner, uint256 amount);

    /**
     * @notice Initializes the GoldLottery contract.
     * @param _vrfCoordinator The address of the Chainlink VRF Coordinator.
     * @param _subscriptionId The Chainlink VRF subscription ID.
     * @param _keyHash The Chainlink VRF key hash.
     */
    constructor(
        address _vrfCoordinator, // Sepolia coordinator : 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        uint64 _subscriptionId,
        bytes32 _keyHash // 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
    }

    /**
     * @notice Adds a participant to the lottery with a specific number of chances.
     * @dev Called by the GoldToken contract after tokens are minted.
     * @param participant The address of the participant.
     * @param amount The number of tokens minted by the participant.
     */
    function enterLottery(address participant, uint256 amount) external {
        require(participant != address(0), "Invalid participant address");
        require(amount > 0, "Amount must be greater than 0");

        // Update the total tokens minted
        tokensMinted += amount;

        // Add chances for the participant
        if (chances[participant] == 0) {
            participants.push(participant);
        }
        chances[participant] += amount;

        emit LotteryEntered(participant, amount);

        // Trigger the lottery if 1000 tokens have been minted
        if (tokensMinted >= 1000) {
            drawLottery();
        }
    }

    /**
     * @notice Adds fees to the lottery balance.
     * @dev Called by the GoldToken contract to deposit fees into the lottery.
     * @param amount The amount of fees to deposit.
     */
    function depositFees(uint256 amount) external payable {
        require(msg.value == amount, "Incorrect fee amount");
        lotteryBalance += amount;
    }

    /**
     * @notice Triggers the lottery to pick a random winner.
     * @dev Uses Chainlink VRF to fairly pick a winner based on the minted tokens.
     */
    function drawLottery() internal {
        require(participants.length > 0, "No participants in the lottery");
        require(lotteryBalance > 0, "No funds in the lottery");

        // Request randomness from Chainlink VRF
        vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1 // Request 1 random word
        );
    }

    /**
     * @notice Callback function for Chainlink VRF to handle randomness.
     * @dev Picks a random winner based on the randomness returned by Chainlink VRF.
     * @param requestId The ID of the randomness request.
     * @param randomWords The array of random words returned by Chainlink VRF.
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 totalChances = 0;

        // Calculate total chances
        for (uint256 i = 0; i < participants.length; i++) {
            totalChances += chances[participants[i]];
        }

        // Select the winner based on randomness
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

        // Payout the winner
        (bool success, ) = winner.call{value: lotteryBalance}("");
        require(success, "Transfer to winner failed");

        emit LotteryWinner(winner, lotteryBalance);

        // Reset the lottery
        lastWinner = winner;
        lastPayout = lotteryBalance;
        delete participants;
        tokensMinted = 0;
        lotteryBalance = 0;
    }

    /**
     * @notice Retrieves the current list of participants.
     * @return An array of addresses of participants in the lottery.
     */
    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    /**
     * @notice Retrieves the number of chances for a given participant.
     * @param participant The address of the participant.
     * @return The number of chances the participant has in the current lottery.
     */
    function getChances(address participant) external view returns (uint256) {
        return chances[participant];
    }

    /**
     * @notice Fallback function to receive ETH directly.
     * @dev This allows the contract to accept ETH for the lottery balance.
     */
    receive() external payable {
        lotteryBalance += msg.value;
    }
}

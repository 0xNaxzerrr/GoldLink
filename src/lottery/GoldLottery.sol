// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "../interfaces/IGoldLottery.sol";

contract GoldLottery is IGoldLottery, VRFConsumerBaseV2Plus {
    error TransferFailed();
    bytes32 private immutable KEY_HASH;
    uint256 private immutable SUBSCRIPTION_ID;
    uint32 private immutable CALLBACK_GAS_LIMIT;
    uint16 private immutable REQUEST_CONFIRMATIONS;
    uint32 private constant NUM_WORDS = 1;
    bool private constant NATIVE_PAYMENT = true;

    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
    }

    uint256 public tokensMinted;
    uint256 public lotteryBalance;
    address public lastWinner;
    uint256 public lastPayout;
    address[] private participants;
    mapping(address => uint256) private chances;
    mapping(uint256 => RequestStatus) private s_requests;

    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subscriptionId,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        require(_callbackGasLimit >= 100000, "Callback gas limit too low");
        require(_requestConfirmations >= 3, "Min confirmations not met");

        KEY_HASH = _keyHash;
        SUBSCRIPTION_ID = _subscriptionId;
        CALLBACK_GAS_LIMIT = _callbackGasLimit;
        REQUEST_CONFIRMATIONS = _requestConfirmations;
    }

    function enterLottery(address participant, uint256 amount) external {
        if (participant == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        tokensMinted += amount;
        if (chances[participant] == 0) participants.push(participant);
        chances[participant] += amount;

        emit LotteryEntered(participant, amount);
    }

    function depositFees(uint256 amount) external payable {
        require(msg.value >= amount, "Insufficient fee amount");
        lotteryBalance += amount;
    }

    function drawLottery() external returns (uint256) {
        return _drawLottery();
    }

    function _drawLottery() private returns (uint256 requestId) {
        if (participants.length == 0) revert NoParticipants();
        if (lotteryBalance == 0) revert NoBalance();

        requestId = IVRFCoordinatorV2Plus(address(s_vrfCoordinator))
            .requestRandomWords(
                VRFV2PlusClient.RandomWordsRequest({
                    keyHash: KEY_HASH,
                    subId: SUBSCRIPTION_ID,
                    requestConfirmations: REQUEST_CONFIRMATIONS,
                    callbackGasLimit: CALLBACK_GAS_LIMIT,
                    numWords: NUM_WORDS,
                    extraArgs: VRFV2PlusClient._argsToBytes(
                        VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                    )
                })
            );

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](NUM_WORDS),
            exists: true,
            fulfilled: false
        });

        emit RequestSent(requestId, NUM_WORDS);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        if (!s_requests[requestId].exists) revert RequestNotExists();
        if (s_requests[requestId].fulfilled) revert RequestAlreadyFulfilled();

        address winner = _selectWinner(randomWords[0]);
        _distributePrize(winner);
        _resetLottery(requestId, randomWords);
    }

    function _selectWinner(uint256 randomWord) private view returns (address) {
        uint256 totalChances = _calculateTotalChances();
        uint256 randomChance = randomWord % totalChances;
        uint256 cumulativeChances = 0;

        uint256 participe = participants.length;
        
        for (uint256 i = 0; i < participe; i++) {
            cumulativeChances += chances[participants[i]];
            if (randomChance < cumulativeChances) {
                return participants[i];
            }
        }

        return participants[participants.length - 1];
    }

    function _calculateTotalChances() private view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < participants.length; i++) {
            total += chances[participants[i]];
        }
        return total;
    }

    function _distributePrize(address winner) private {
        uint256 prize = lotteryBalance;
        lotteryBalance = 0;
        lastWinner = winner;
        lastPayout = prize;

        (bool success, ) = winner.call{value: prize}("");
        if (!success) revert TransferFailed();

        emit LotteryWinner(winner, prize);
    }

    function _resetLottery(
        uint256 requestId,
        uint256[] memory randomWords
    ) private {
        s_requests[requestId].fulfilled = true;
        s_requests[requestId].randomWords = randomWords;

        for (uint256 i = 0; i < participants.length; i++) {
            chances[participants[i]] = 0;
        }
        delete participants;
        tokensMinted = 0;

        emit RequestFulfilled(requestId, randomWords);
    }

    // function setCoordinator(
    //     address newCoordinator
    // ) external override(IGoldLottery, VRFConsumerBaseV2Plus) onlyOwner {
    //     if (newCoordinator == address(0)) revert InvalidAddress();
    //     revert("Coordinator can't be changed - immutable");
    // }

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

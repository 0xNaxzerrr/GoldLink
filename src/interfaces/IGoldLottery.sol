// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGoldLottery {
    error InvalidAddress();
    error InvalidAmount();
    error NoParticipants();
    error NoBalance();
    error RequestNotExists();
    error RequestAlreadyFulfilled();

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event LotteryEntered(address indexed participant, uint256 chances);
    event LotteryWinner(address indexed winner, uint256 amount);

    function initialize() external;
    function setCoordinator(address newCoordinator) external;
    function enterLottery(address participant, uint256 amount) external;
    function depositFees(uint256 amount) external payable;
    // function drawLottery() external returns (uint256);  // Fonction manquante
    function getParticipants() external view returns (address[] memory);
    function getChances(address participant) external view returns (uint256);
}
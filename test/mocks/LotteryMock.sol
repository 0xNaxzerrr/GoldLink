// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../src/interfaces/IGoldLottery.sol";

contract LotteryMock is IGoldLottery {
    uint256 public tokensMinted;
    uint256 public lotteryBalance;
    address public lastWinner;
    uint256 public lastPayout;
    
    function initialize() external {}

    function setCoordinator(address) external {}

    function enterLottery(address participant, uint256 amount) external {
        tokensMinted += amount;
        emit LotteryEntered(participant, amount);
    }

    function depositFees(uint256 amount) external payable {
        if (msg.value != amount) revert InvalidAmount();
        lotteryBalance += amount;
    }

    // Ajout de la fonction manquante
    function drawLottery() external returns (uint256) {
        // Simulation simple d'un tirage
        if (tokensMinted == 0) revert NoParticipants();
        if (lotteryBalance == 0) revert NoBalance();
        
        lastPayout = lotteryBalance;
        lotteryBalance = 0;
        tokensMinted = 0;
        
        return 1; // ID de requête fictif
    }

    function getParticipants() external pure returns (address[] memory) {
        address[] memory participants = new address[](0);
        return participants;
    }

    function getChances(address) external pure returns (uint256) {
        return 0;
    }

    receive() external payable {
        lotteryBalance += msg.value;
    }
}
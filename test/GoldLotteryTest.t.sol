// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/GoldLottery.sol";
import "@chainlink/contracts/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract GoldLotteryTest is Test {
    GoldLottery public goldLottery;
    VRFCoordinatorV2Mock public vrfCoordinator;

    address public owner = address(0xABCD);
    address public participant1 = address(0x1234);
    address public participant2 = address(0x5678);

    uint64 public subscriptionId = 1;

    function setUp() public {
        vm.startPrank(owner);

        vrfCoordinator = new VRFCoordinatorV2Mock(0.1 ether, 0.1 ether);

        subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, 1 ether);

        goldLottery = new GoldLottery(
            subscriptionId,
            address(vrfCoordinator),
            owner
        );

        vrfCoordinator.addConsumer(subscriptionId, address(goldLottery));

        vm.stopPrank();
    }

    function testEnterLottery() public {
        vm.prank(participant1);
        goldLottery.enterLottery(participant1, 500e18);

        assertEq(goldLottery.tokensMinted(), 500e18);
        assertEq(goldLottery.getChances(participant1), 500e18);
    }

    function testDrawLottery() public {
        vm.deal(owner, 2 ether);

        vm.prank(owner);
        goldLottery.depositFees{value: 1 ether}(1 ether);

        vm.prank(participant1);
        goldLottery.enterLottery(participant1, 600e18);
        assertEq(
            goldLottery.getChances(participant1),
            600e18,
            "Participant1 chances should be 600e18"
        );

        vm.prank(participant2);
        goldLottery.enterLottery(participant2, 400e18);
        assertEq(
            goldLottery.getChances(participant2),
            400e18,
            "Participant2 chances should be 400e18"
        );

        uint256 balance = address(goldLottery).balance;
        console.log("Balance:", balance);

        vm.prank(owner);
        uint256 requestId = goldLottery.drawLottery();

        assertTrue(requestId > 0, "RequestId should be greater than 0");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/lottery/GoldLottery.sol";
import "../mocks/VRFCoordinatorV2_5Mock.sol";

contract GoldLotteryTest is Test {
    GoldLottery public lottery;
    VRFCoordinatorV2_5Mock public vrfCoordinator;
    
    bytes32 constant KEY_HASH = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint256 constant SUBSCRIPTION_ID = 1;
    uint32 constant CALLBACK_GAS_LIMIT = 100000;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address newCoordinator = makeAddr("newCoordinator");

    event LotteryEntered(address indexed participant, uint256 chances);
    event LotteryWinner(address indexed winner, uint256 amount);
function setUp() public {
    console2.log("=== Debug Setup Start ===");
    
    // 1. Deploy VRF Coordinator
    vrfCoordinator = new VRFCoordinatorV2_5Mock();
    console2.log("VRF Coordinator deployed at:", address(vrfCoordinator));
    
    // 2. Deploy Lottery implementation with owner
    vm.prank(address(this));
    lottery = new GoldLottery(
        address(vrfCoordinator),
        KEY_HASH,
        SUBSCRIPTION_ID,
        CALLBACK_GAS_LIMIT,
        REQUEST_CONFIRMATIONS
    );
    console2.log("Lottery deployed at:", address(lottery));
    
    try lottery.initialize() {
        console2.log("Initialization successful");
    } catch Error(string memory reason) {
        console2.log("Initialization failed:", reason);
    }
    
    console2.log("Owner after initialization attempt:", lottery.owner());
    
    // Setup test accounts
    vm.deal(alice, 100 ether);
    vm.deal(bob, 100 ether);
    
    console2.log("=== Setup Complete ===");
}

    function testInitialize() public {
        assertEq(lottery.owner(), address(this));
    }

    function testSetCoordinator() public {
        lottery.setCoordinator(newCoordinator);
    }

    function testEnterLottery() public {
        vm.startPrank(alice);
        lottery.depositFees{value: 1 ether}(1 ether);
        lottery.enterLottery(alice, 1 ether); 
        vm.stopPrank();
        
        assertEq(lottery.getChances(alice), 1 ether);
        assertEq(lottery.tokensMinted(), 1 ether);
    }

    function testDepositFees() public {
        vm.prank(alice);
        lottery.depositFees{value: 1 ether}(1 ether);
        
        assertEq(address(lottery).balance, 1 ether);
        assertEq(lottery.lotteryBalance(), 1 ether);
    }

    function testDrawLotteryAndFulfillment() public {
        vm.startPrank(alice);
        lottery.depositFees{value: 2 ether}(2 ether);
        lottery.enterLottery(alice, 1000e18);
        vm.stopPrank();
        
        vm.startPrank(bob);
        lottery.enterLottery(bob, 500e18);
        vm.stopPrank();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        
        vrfCoordinator.fulfillRandomWords(1, address(lottery));

        assertTrue(lottery.lastWinner() == alice || lottery.lastWinner() == bob);
        assertGt(lottery.lastPayout(), 0);
    }

    function testFailInvalidCoordinator() public {
        vm.expectRevert(IGoldLottery.InvalidAddress.selector);
        lottery.setCoordinator(address(0));
    }

    function testFailInvalidAddress() public {
        vm.expectRevert(IGoldLottery.InvalidAddress.selector);
        lottery.enterLottery(address(0), 1 ether);
    }

    function testFailInvalidAmount() public {
        vm.expectRevert(IGoldLottery.InvalidAmount.selector);
        lottery.enterLottery(alice, 0);
    }

    receive() external payable {}
}
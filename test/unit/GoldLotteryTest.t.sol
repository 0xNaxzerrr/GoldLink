// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import "forge-std/Test.sol";
// import "../../src/lottery/GoldLottery.sol";
// import "@chainlink/contracts/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
// import "../mocks/LotteryMock.sol";

// contract GoldLotteryTest is Test {
//     GoldLottery public lottery;
//     LotteryMock public mockLottery;
//     VRFCoordinatorV2_5Mock public coordinator;
    
//     bytes32 constant KEY_HASH = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
//     uint256 constant SUBSCRIPTION_ID = 1;
//     uint32 constant CALLBACK_GAS_LIMIT = 100000;
//     uint16 constant REQUEST_CONFIRMATIONS = 3;
    
//     address alice = makeAddr("alice");
//     address bob = makeAddr("bob");

//     function setUp() public {
//         // 1. Deploy mocks
//         coordinator = new VRFCoordinatorV2_5Mock(
//             0.25 ether,  // _baseFee
//             1e9,        // _gasPrice
//             1e18       // _weiPerUnitLink
//         );
//         mockLottery = new LotteryMock();
        
//         // 2. Deploy Lottery avec le mock
//         lottery = new GoldLottery(
//             address(coordinator),
//             KEY_HASH,
//             SUBSCRIPTION_ID,
//             CALLBACK_GAS_LIMIT,
//             REQUEST_CONFIRMATIONS
//         );
//         lottery.initialize();
        
//         // 3. Setup VRF subscription
//         coordinator.createSubscription();
//         coordinator.fundSubscription(SUBSCRIPTION_ID, 10 ether);
//         coordinator.addConsumer(SUBSCRIPTION_ID, address(lottery));
        
//         // 4. Fund test accounts
//         vm.deal(alice, 100 ether);
//         vm.deal(bob, 100 ether);
//     }

//     function testEnterLottery() public {
//         vm.startPrank(alice);
//         lottery.depositFees{value: 1 ether}(1 ether);
//         lottery.enterLottery(alice, 1 ether);
//         vm.stopPrank();
        
//         assertEq(lottery.getChances(alice), 1 ether);
//         assertEq(lottery.tokensMinted(), 1 ether);
//     }

//     function testDrawLottery() public {
//         console2.log("Starting lottery draw test...");
        
//         // Setup
//         vm.startPrank(alice);
//         lottery.depositFees{value: 2 ether}(2 ether);
//         lottery.enterLottery(alice, 1000e18);
//         console2.log("Alice entered with 1000e18 chances");
//         vm.stopPrank();
        
//         vm.startPrank(bob);
//         lottery.depositFees{value: 1 ether}(1 ether);
//         lottery.enterLottery(bob, 500e18);
//         console2.log("Bob entered with 500e18 chances");
//         vm.stopPrank();

//         uint256 initialBalance = lottery.lotteryBalance();
        
//         // Execute
//         vm.prank(address(this));
//         uint256 requestId = lottery.drawLottery();
        
//         // Simulate VRF V2.5 response
//         coordinator.fulfillRandomWordsWithOverride(
//             requestId,
//             address(lottery),
//             new uint256[](1)  // Laisse le mock générer les mots aléatoires
//         );

//         // Verify
//         assertTrue(lottery.lastWinner() == alice || lottery.lastWinner() == bob);
//         assertEq(lottery.lastPayout(), initialBalance);
//         assertEq(lottery.lotteryBalance(), 0);
//         assertEq(lottery.tokensMinted(), 0);
//         assertEq(lottery.getParticipants().length, 0);
//     }

//     function testRevertOnInvalidAddress() public {
//         vm.expectRevert(IGoldLottery.InvalidAddress.selector);
//         lottery.enterLottery(address(0), 1 ether);
//     }

//     function testRevertOnInvalidAmount() public {
//         vm.expectRevert(IGoldLottery.InvalidAmount.selector);
//         lottery.enterLottery(alice, 0);
//     }

//     function testRevertOnNoParticipants() public {
//         vm.expectRevert(IGoldLottery.NoParticipants.selector);
//         lottery.drawLottery();
//     }

//     function testRevertOnNoBalance() public {
//         vm.startPrank(alice);
//         lottery.enterLottery(alice, 1000e18);
//         vm.stopPrank();

//         vm.expectRevert(IGoldLottery.NoBalance.selector);
//         lottery.drawLottery();
//     }

//     function testLotteryMockInteraction() public {
//         // Test que le mock fonctionne correctement
//         vm.startPrank(alice);
//         mockLottery.depositFees{value: 1 ether}(1 ether);
//         mockLottery.enterLottery(alice, 1 ether);
//         vm.stopPrank();

//         assertEq(mockLottery.tokensMinted(), 1 ether);
//         assertEq(mockLottery.lotteryBalance(), 1 ether);
//     }

//     receive() external payable {}
// }
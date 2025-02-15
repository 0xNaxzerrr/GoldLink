// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import "forge-std/Test.sol";
// import "../../src/lottery/GoldLottery.sol";

// contract GoldLotteryTest is Test {
//     GoldLottery public lottery;

//     address public constant PLAYER1 = address(1);
//     address public constant PLAYER2 = address(2);
//     address public constant PLAYER3 = address(3);
//     address public constant VRF_COORDINATOR = address(0x100);

//     bytes32 public constant KEY_HASH = keccak256("test_keyhash");
//     uint64 public constant SUBSCRIPTION_ID = 1;
//     uint32 public constant CALLBACK_GAS_LIMIT = 100000;
//     uint16 public constant REQUEST_CONFIRMATIONS = 3;

//     event LotteryEntered(address indexed participant, uint256 amount);
//     event LotteryWinner(address indexed winner, uint256 prize);
//     event RequestSent(uint256 indexed requestId, uint32 numWords);
//     event RequestFulfilled(uint256 indexed requestId, uint256[] randomWords);

//     function setUp() public {
//         // Deploy Lottery contract with mock VRF coordinator address
//         lottery = new GoldLottery(
//             VRF_COORDINATOR,
//             KEY_HASH,
//             SUBSCRIPTION_ID,
//             CALLBACK_GAS_LIMIT,
//             REQUEST_CONFIRMATIONS
//         );

//         // Give test accounts some ETH
//         vm.deal(PLAYER1, 10 ether);
//         vm.deal(PLAYER2, 10 ether);
//         vm.deal(PLAYER3, 10 ether);
//         vm.deal(address(this), 10 ether);
//     }

//     function test_EnterLottery() public {
//         vm.expectEmit(true, true, true, true);
//         emit LotteryEntered(PLAYER1, 1 ether);

//         vm.prank(PLAYER1);
//         lottery.enterLottery(PLAYER1, 1 ether);

//         assertEq(lottery.tokensMinted(), 1 ether);
//         assertEq(lottery.getChances(PLAYER1), 1 ether);

//         address[] memory participants = lottery.getParticipants();
//         assertEq(participants.length, 1);
//         assertEq(participants[0], PLAYER1);
//     }

//     function test_EnterLotteryMultiplePlayers() public {
//         vm.prank(PLAYER1);
//         lottery.enterLottery(PLAYER1, 1 ether);

//         vm.prank(PLAYER2);
//         lottery.enterLottery(PLAYER2, 2 ether);

//         assertEq(lottery.tokensMinted(), 3 ether);
//         assertEq(lottery.getChances(PLAYER1), 1 ether);
//         assertEq(lottery.getChances(PLAYER2), 2 ether);

//         address[] memory participants = lottery.getParticipants();
//         assertEq(participants.length, 2);
//         assertEq(participants[0], PLAYER1);
//         assertEq(participants[1], PLAYER2);
//     }

//     function test_AccumulateChances() public {
//         vm.prank(PLAYER1);
//         lottery.enterLottery(PLAYER1, 1 ether);

//         vm.prank(PLAYER1);
//         lottery.enterLottery(PLAYER1, 2 ether);

//         assertEq(lottery.tokensMinted(), 3 ether);
//         assertEq(lottery.getChances(PLAYER1), 3 ether);

//         address[] memory participants = lottery.getParticipants();
//         assertEq(participants.length, 1);
//     }

//     function test_RevertWhen_EnterLotteryZeroAmount() public {
//         vm.prank(PLAYER1);
//         vm.expectRevert(IGoldLottery.InvalidAmount.selector);
//         lottery.enterLottery(PLAYER1, 0);
//     }

//     function test_RevertWhen_EnterLotteryZeroAddress() public {
//         vm.prank(PLAYER1);
//         vm.expectRevert(IGoldLottery.InvalidAddress.selector);
//         lottery.enterLottery(address(0), 1 ether);
//     }

//     function test_DepositFees() public {
//         lottery.depositFees{value: 1 ether}(1 ether);
//         assertEq(lottery.lotteryBalance(), 1 ether);
//     }

//     function test_RevertWhen_InsufficientFeeDeposit() public {
//         vm.expectRevert("Insufficient fee amount");
//         lottery.depositFees{value: 0.5 ether}(1 ether);
//     }

//     function test_ReceiveEther() public {
//         (bool success, ) = address(lottery).call{value: 1 ether}("");
//         assertTrue(success);
//         assertEq(lottery.lotteryBalance(), 1 ether);
//     }

//     function test_CompleteLotteryFlow() public {
//         // Setup players with different chances
//         vm.prank(PLAYER1);
//         lottery.enterLottery(PLAYER1, 1 ether); // 1/3 chance

//         vm.prank(PLAYER2);
//         lottery.enterLottery(PLAYER2, 2 ether); // 2/3 chance

//         // Add prize money
//         lottery.depositFees{value: 5 ether}(5 ether);
//         assertEq(lottery.lotteryBalance(), 5 ether);

//         // Start lottery draw
//         vm.prank(VRF_COORDINATOR); // Simulate VRF coordinator
//         uint256 requestId = lottery.drawLottery();

//         // Prepare random words response
//         uint256[] memory randomWords = new uint256[](1);
//         randomWords[0] = 12345; // This will determine the winner based on chances

//         // Mock VRF callback
//         vm.prank(VRF_COORDINATOR);
//         lottery.fulfillRandomWords(requestId, randomWords);

//         // Verify lottery state after draw
//         assertEq(lottery.tokensMinted(), 0); // Tokens reset
//         assertEq(lottery.lotteryBalance(), 0); // Prize distributed
//         assertTrue(
//             lottery.lastWinner() == PLAYER1 || lottery.lastWinner() == PLAYER2
//         );
//         assertEq(lottery.lastPayout(), 5 ether);

//         // Verify winner got paid
//         assertTrue(lottery.lastWinner().balance >= 5 ether);
//     }

//     function test_RevertWhen_DrawLotteryNoParticipants() public {
//         vm.prank(VRF_COORDINATOR);
//         vm.expectRevert(IGoldLottery.NoParticipants.selector);
//         lottery.drawLottery();
//     }

//     function test_RevertWhen_DrawLotteryNoBalance() public {
//         vm.prank(PLAYER1);
//         lottery.enterLottery(PLAYER1, 1 ether);

//         vm.prank(VRF_COORDINATOR);
//         vm.expectRevert(IGoldLottery.NoBalance.selector);
//         lottery.drawLottery();
//     }

//     function test_RevertWhen_UnauthorizedVRFCallback() public {
//         // Setup valid lottery state
//         vm.prank(PLAYER1);
//         lottery.enterLottery(PLAYER1, 1 ether);
//         lottery.depositFees{value: 1 ether}(1 ether);

//         vm.prank(VRF_COORDINATOR);
//         uint256 requestId = lottery.drawLottery();

//         uint256[] memory randomWords = new uint256[](1);
//         randomWords[0] = 12345;

//         // Try to fulfill from unauthorized address
//         vm.prank(PLAYER1);
//         vm.expectRevert("Only VRF coordinator can fulfill");
//         lottery.fulfillRandomWords(requestId, randomWords);
//     }

//     receive() external payable {}
// }

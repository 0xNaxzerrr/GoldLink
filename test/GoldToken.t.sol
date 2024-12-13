// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/GoldToken.sol";
import "../src/GoldLottery.sol";
import "../src/MockPriceFeed.sol";
import "@chainlink/contracts/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract GoldTokenTest is Test {
    GoldToken public goldToken;
    GoldLottery public goldLottery;
    VRFCoordinatorV2Mock public vrfCoordinator;
    MockPriceFeed public mockFeed;

    address public owner = address(0xABCD);
    address public user = address(0x1234);

    uint256 public initialPrice = 1e15;
    uint64 public subId;

    function setUp() public {
        vm.startPrank(owner);

        vrfCoordinator = new VRFCoordinatorV2Mock(0.1 ether, 0.1 ether);

        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 1 ether);

        mockFeed = new MockPriceFeed(int256(initialPrice));

        goldLottery = new GoldLottery(subId, address(vrfCoordinator), owner);
        vrfCoordinator.addConsumer(subId, address(goldLottery));

        goldToken = new GoldToken(
            address(mockFeed),
            payable(address(goldLottery))
        );

        vm.stopPrank();
    }
    function testSetBridgeAddress() public {
        address newBridge = address(0x5678);
        vm.prank(owner);
        goldToken.setBridgeAddress(newBridge);
        assertEq(goldToken.bridgeAddress(), newBridge);
    }
    function testBridgeMint() public {
        address bridge = address(0x5678);
        vm.prank(owner);
        goldToken.setBridgeAddress(bridge);

        vm.prank(bridge);
        goldToken.bridgeMint(user, 100e18);

        assertEq(goldToken.balanceOf(user), 100e18);
    }

    function testFailMintWithoutEth() public {
        vm.prank(user);
        goldToken.mint{value: 0}();
    }

    function testFailBurnTooMuch() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        goldToken.mint{value: 0.5 ether}();

        vm.prank(user);
        goldToken.burn(500e18);
    }

    function testMintTokens() public {
        vm.deal(user, 1 ether);

        vm.prank(user);
        goldToken.mint{value: 0.5 ether}();

        assertEq(goldToken.balanceOf(user), 475e18);
    }

    function testBurnTokens() public {
        vm.deal(user, 1 ether);

        vm.prank(user);
        goldToken.mint{value: 0.5 ether}();

        uint256 initialBalance = user.balance;

        vm.prank(user);
        goldToken.burn(475e18);

        uint256 expectedBalance = initialBalance + 0.45 ether;
        uint256 actualBalance = user.balance;

        uint256 allowedDifference = 2e15;

        assertApproxEqAbs(
            actualBalance,
            expectedBalance,
            allowedDifference,
            "Balance after burn should be close to expected"
        );
    }
}

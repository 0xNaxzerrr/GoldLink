// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/GoldToken.sol";
import "../src/GoldBridge.sol";
import "../src/GoldLottery.sol";
import "../src/MockPriceFeed.sol";
import "../src/MockRouter.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";
import "@chainlink/contracts/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract GoldBridgeTest is Test {
    GoldToken public goldToken;
    GoldBridge public goldBridge;
    MockRouter public mockRouter;
    MockPriceFeed public mockFeed;
    GoldLottery public goldLottery;
    VRFCoordinatorV2Mock public vrfCoordinator;

    address public owner = address(0xABCD);
    address public user = address(0x1234);
    uint64 public subId;
    uint64 public constant destinationChainId = 10002;

    function setUp() public {
        vm.startPrank(owner);


        vrfCoordinator = new VRFCoordinatorV2Mock(0.1 ether, 0.1 ether);


        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 1 ether);


        mockFeed = new MockPriceFeed(1e15); 
        


        goldLottery = new GoldLottery(subId, address(vrfCoordinator), owner);
        vrfCoordinator.addConsumer(subId, address(goldLottery));


        mockRouter = new MockRouter();
        goldToken = new GoldToken(
            address(mockFeed),
            payable(address(goldLottery))
        );
        bytes memory remoteContract = abi.encodePacked(address(0x9999));
        goldBridge = new GoldBridge(
            address(mockRouter),
            address(goldToken),
            remoteContract,
            destinationChainId
        );


        goldToken.setBridgeAddress(address(goldBridge));


        goldToken.adminMint(user, 1000e18);

        vm.stopPrank();

        vm.prank(user);
        goldToken.approve(address(goldBridge), type(uint256).max);
    }

    function testBridgeOut() public {
        
        vm.deal(address(goldBridge), 1 ether);
        uint256 userBalanceBefore = goldToken.balanceOf(user);
        uint256 amount = 100e18;
        address recipientOnDestination = address(0x5678);

        vm.prank(user);
        goldBridge.bridgeOut(recipientOnDestination, amount);

        uint256 userBalanceAfter = goldToken.balanceOf(user);
        assertEq(userBalanceAfter, userBalanceBefore - amount);
    }

    function testCcipReceive() public {
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(goldToken),
            amount: 50e18
        });


        Client.Any2EVMMessage memory fakeMessage = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: destinationChainId,
            sender: abi.encodePacked(address(0x9999)),
            data: abi.encode(user, 50e18),
            destTokenAmounts: tokenAmounts
        });

        uint256 userBalanceBefore = goldToken.balanceOf(user);


        vm.prank(address(mockRouter));
        goldBridge.ccipReceive(fakeMessage);

        uint256 userBalanceAfter = goldToken.balanceOf(user);
        assertEq(userBalanceAfter, userBalanceBefore + 50e18);
    }
}

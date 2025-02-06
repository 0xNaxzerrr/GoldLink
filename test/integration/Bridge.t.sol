// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/tokens/GoldToken.sol";
import "../../src/bridge/GoldBridge.sol";
import "../../src/lottery/GoldLottery.sol";
import "../mocks/PriceFeedMock.sol";
import "../mocks/RouterMock.sol";
import "../mocks/VRFCoordinatorV2_5Mock.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";

contract BridgeIntegrationTest is Test {
    GoldToken public goldToken;
    GoldBridge public goldBridge;
    RouterMock public router;
    PriceFeedMock public xauUsdFeed;
    PriceFeedMock public ethUsdFeed;
    GoldLottery public lottery;
    VRFCoordinatorV2_5Mock public vrfCoordinator;

    address owner = makeAddr("owner");
    address user = makeAddr("user");
    uint64 constant DESTINATION_CHAIN_ID = 97; // BSC Testnet
    
    event MessageSent(bytes32 indexed messageId, uint64 indexed destinationChainId, address recipient, uint256 amount);

    function setUp() public {
        vm.startPrank(owner);

        // Setup VRF
        vrfCoordinator = new VRFCoordinatorV2_5Mock();
        uint256 subId = uint256(vrfCoordinator.createSubscription());
        vrfCoordinator.fundSubscription(subId, 1 ether);

        // Setup contracts
        bytes32 keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
        uint32 callbackGasLimit = 2500000;
        uint16 requestConfirmations = 3;

        lottery = new GoldLottery(
            address(vrfCoordinator),
            keyHash, 
            subId,
            callbackGasLimit,
            requestConfirmations
        );
        vrfCoordinator.addConsumer(subId, address(lottery));

        router = new RouterMock();

        goldToken = new GoldToken(
            address(xauUsdFeed),
            address(ethUsdFeed),
            payable(address(lottery))
        );
        goldToken.initialize();

        bytes memory remoteContract = abi.encodePacked(makeAddr("remoteBridge"));
        goldBridge = new GoldBridge(
            address(router),
            address(goldToken),
            remoteContract,
            DESTINATION_CHAIN_ID
        );
        goldBridge.initialize();

        goldToken.setBridgeAddress(address(goldBridge));
        goldToken.adminMint(user, 1000 ether);

        vm.stopPrank();

        vm.prank(user);
        goldToken.approve(address(goldBridge), type(uint256).max);
        vm.deal(address(goldBridge), 100 ether);
    }

    function testBridgeOut() public {
        uint256 amount = 100 ether;
        address recipient = makeAddr("recipient");

        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit MessageSent(bytes32(0), DESTINATION_CHAIN_ID, recipient, amount);
        goldBridge.bridgeOut(recipient, amount);

        assertEq(goldToken.balanceOf(user), 900 ether);
    }

    function testCcipReceive() public {
        uint256 amount = 50 ether;
    
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: DESTINATION_CHAIN_ID,
            sender: abi.encode(address(router)),
            data: abi.encode(user, amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        uint256 balanceBefore = goldToken.balanceOf(user);
        
        vm.prank(address(router));
        goldBridge.ccipReceive(message);

        assertEq(goldToken.balanceOf(user), balanceBefore + amount);
    }
}
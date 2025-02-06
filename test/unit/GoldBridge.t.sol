// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console2.sol";  // Changement vers console2
import "../../src/bridge/GoldBridge.sol";
import "../../src/tokens/GoldToken.sol";
import "../mocks/RouterMock.sol";
import "../mocks/PriceFeedMock.sol"; // Ajout de l'import
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";

contract GoldBridgeTest is Test {
    GoldBridge public implementation;
    GoldBridge public bridge;
    GoldToken public token;
    RouterMock public router;

    // Paramètres de test
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    bytes remoteContract = hex"1234"; // Format hexadécimal correct
    uint64 destinationChainId = 97; // BSC Testnet
    uint256 constant INITIAL_BALANCE = 1000 ether;
    uint256 constant BRIDGE_FUNDS = 100 ether;

    event MessageSent(
        bytes32 indexed messageId, 
        uint64 indexed destinationChainId,
        address recipient,
        uint256 amount
    );
    event TokensBridged(address indexed recipient, uint256 amount);
    event FundsReceived(address sender, uint256 amount);

    function setUp() public {
        vm.warp(1000);
        console2.log("=== Debug Setup Start ===");
        address owner = address(this);
        
        // 1. Mock Setup
        router = new RouterMock();
        PriceFeedMock xauUsdFeed = new PriceFeedMock();
        PriceFeedMock ethUsdFeed = new PriceFeedMock();
        
        xauUsdFeed.setPrice(2000 * 1e8);
        ethUsdFeed.setPrice(3000 * 1e8);
        console2.log("Mocks configured");

        // 2. Token Setup
        token = new GoldToken(
            address(xauUsdFeed),
            address(ethUsdFeed),
            payable(owner)
        );
        
        vm.startPrank(owner);
        token.initialize();
        require(token.owner() == owner, "Token init failed");
        vm.stopPrank();
        console2.log("Token setup complete at:", address(token));

        // 3. Bridge Setup
        implementation = new GoldBridge(
            address(router),
            address(token),
            remoteContract,
            destinationChainId
        );
        require(address(implementation) != address(0), "Bridge impl failed");
        console2.log("Bridge impl at:", address(implementation));

        // 4. Create and Initialize Proxy
        bytes memory initData = "";
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        bridge = GoldBridge(payable(address(proxy)));
        console2.log("Bridge proxy at:", address(bridge));

        // 5. Bridge Configuration
        vm.startPrank(owner);
        bridge.initialize();
        require(bridge.owner() == owner, "Bridge init failed");
        token.setBridgeAddress(address(bridge));
        vm.stopPrank();

        // 6. Final Setup
        vm.deal(address(bridge), BRIDGE_FUNDS);
        token.adminMint(alice, INITIAL_BALANCE);
        vm.prank(alice);
        token.approve(address(bridge), type(uint256).max);
        
        console2.log("=== Setup Complete ===");
    }

    // Tests principaux
    function testInitialState() public view {
        assertEq(address(bridge.router()), address(router));
        assertEq(address(bridge.goldToken()), address(token));
        assertEq(bridge.destinationChainId(), destinationChainId);
        assertEq(bridge.remoteContractOnDestinationChain(), remoteContract);
    }

    // Tests additionnels
    function testSetRemoteContract() public {
        bytes memory newRemoteContract = "0x5678";
        vm.prank(bridge.owner());
        bridge.setRemoteContract(newRemoteContract);
        assertEq(bridge.remoteContractOnDestinationChain(), newRemoteContract);
    }

    function testSetDestinationChainId() public {
        uint64 newChainId = 56;
        vm.prank(bridge.owner());
        bridge.setDestinationChainId(newChainId);
        assertEq(bridge.destinationChainId(), newChainId);
    }

    function testFailSetRemoteContractUnauthorized() public {
        vm.prank(alice);
        bridge.setRemoteContract("0x5678");
    }

    function testFailSetDestinationChainIdUnauthorized() public {
        vm.prank(alice);
        bridge.setDestinationChainId(56);
    }

    function test_RevertWhen_SetRemoteContractUnauthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        bridge.setRemoteContract(hex"5678");
    }

    function test_RevertWhen_SetDestinationChainIdUnauthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        bridge.setDestinationChainId(56);
    }

    receive() external payable {}
}
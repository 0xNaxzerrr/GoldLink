// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../../src/bridge/GoldBridge.sol";
import "../../src/tokens/GoldToken.sol";
import "../mocks/RouterMock.sol";
import "../mocks/PriceFeedMock.sol";
import "../mocks/LinkTokenMock.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";

contract GoldBridgeTest is Test {
    GoldBridge public initGoldBridge;
    GoldBridge public bridge;
    GoldToken public token;
    IRouterClient public router;
    LinkTokenMock public linkToken;

    uint64 constant BSC_TESTNET_SELECTOR = 12532609583862916517;  
    bytes constant REMOTE_CONTRACT = hex"1234567890abcdef1234567890abcdef12345678"; 
    uint256 constant INITIAL_BALANCE = 1000 ether;
    uint256 constant BRIDGE_FUNDS = 100 ether;

    // Test addresses
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address owner = address(this);

    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainId,
        address recipient,
        uint256 amount
    );
    event TokensBridged(address indexed recipient, uint256 amount);

    function setUp() public {
        vm.warp(1000);
        console2.log("=== Debug Setup Start ===");

        // 1) Déploie les mocks
        router = new RouterMock();
        linkToken = new LinkTokenMock();

        PriceFeedMock xauUsdFeed = new PriceFeedMock();
        PriceFeedMock ethUsdFeed = new PriceFeedMock();
        xauUsdFeed.setPrice(2000 * 1e8);
        ethUsdFeed.setPrice(3000 * 1e8);

        // 2) Déploie et initialise le token
        token = new GoldToken(
            address(xauUsdFeed),
            address(ethUsdFeed),
            payable(owner)
        );
        token.initialize();

        // 3) Déploie le bridge avec proxy
        initGoldBridge = new GoldBridge(
            address(router),
            address(token),
            address(linkToken),
            REMOTE_CONTRACT,
            BSC_TESTNET_SELECTOR
        );

        bytes memory initData = abi.encodeWithSelector(GoldBridge.initialize.selector);
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(initGoldBridge),
            initData
        );
        bridge = GoldBridge(payable(address(proxy)));

        // 4) Configure le bridge
        token.setBridgeAddress(address(bridge));
        bridge.setDestinationChainId(BSC_TESTNET_SELECTOR);
        bridge.setRemoteContract(REMOTE_CONTRACT);

        // 5) Setup les balances et les approbations
        vm.deal(address(bridge), BRIDGE_FUNDS);
        token.adminMint(alice, INITIAL_BALANCE);
        
        // Donner des LINK à Alice au lieu du bridge
        linkToken.mint(alice, 100 ether);
        
        // Alice approuve le bridge pour les tokens et le LINK
        vm.startPrank(alice);
        token.approve(address(bridge), type(uint256).max);
        linkToken.approve(address(bridge), type(uint256).max);
        vm.stopPrank();

        // Configurer le mock router
        RouterMock(address(router)).setNextMessageId(bytes32(uint256(1)));
        RouterMock(address(router)).setFees(0.01 ether);
    }

    function testInitialState() public {
        assertEq(address(bridge.router()), address(router));
        assertEq(address(bridge.goldToken()), address(token));
        assertEq(bridge.destinationChainId(), BSC_TESTNET_SELECTOR);
        assertEq(bridge.remoteContractOnDestinationChain(), REMOTE_CONTRACT);
    }

    function testBridgeOut() public {
        uint256 amount = 1 ether;
        uint256 fees = 0.01 ether;
        uint256 initialTokenBalance = token.balanceOf(alice);
        uint256 initialLinkBalance = linkToken.balanceOf(alice);

        bytes32 expectedMessageId = bytes32(uint256(1));
        RouterMock(address(router)).setNextMessageId(expectedMessageId);
        RouterMock(address(router)).setFees(fees);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit MessageSent(expectedMessageId, BSC_TESTNET_SELECTOR, alice, amount);
        bridge.bridgeOut(alice, amount);

        // Vérifiez les soldes finaux
        assertEq(token.balanceOf(alice), initialTokenBalance - amount);
        assertEq(linkToken.balanceOf(alice), initialLinkBalance - fees);
        assertEq(linkToken.balanceOf(address(router)), fees); // Le router a reçu les fees
    }

    function testCcipReceive() public {
        uint256 amount = 1 ether;
        uint256 initialBalance = token.balanceOf(bob);
        
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: BSC_TESTNET_SELECTOR,
            sender: REMOTE_CONTRACT,
            data: abi.encode(bob, amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.prank(address(router));
        vm.expectEmit(true, true, true, true);
        emit TokensBridged(bob, amount);
        bridge.ccipReceive(message);

        assertEq(token.balanceOf(bob), initialBalance + amount);
    }

    function testSetRemoteContract() public {
        bytes memory newRemoteContract = hex"5678";
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

    // Tests des cas d'erreur
    function test_RevertWhen_InsufficientBalance() public {
        uint256 amount = INITIAL_BALANCE + 1 ether;
        
        vm.prank(alice);
        vm.expectRevert(IGoldBridge.InsufficientBalance.selector);
        bridge.bridgeOut(alice, amount);
    }

    function test_RevertWhen_InsufficientFees() public {
        uint256 amount = 1 ether;
        uint256 fees = 200 ether; // Plus que le solde initial d'Alice (100 ether)
        
        // Brûle les LINK d'Alice en les envoyant à un autre compte
        vm.startPrank(alice);
        uint256 balance = linkToken.balanceOf(alice);
        linkToken.transfer(makeAddr("burn"), balance);
        vm.stopPrank();
        
        // Vérifie que le solde est à 0
        assertEq(linkToken.balanceOf(alice), 0);
        
        // Configure des frais plus élevés que son solde
        RouterMock(address(router)).setFees(fees);
        
        vm.prank(alice);
        vm.expectRevert(IGoldBridge.InsufficientFees.selector);
        bridge.bridgeOut(alice, amount);
    }

    function test_RevertWhen_UnauthorizedRouter() public {
        uint256 amount = 1 ether;
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: BSC_TESTNET_SELECTOR,
            sender: REMOTE_CONTRACT,
            data: abi.encode(bob, amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.prank(alice);
        vm.expectRevert(IGoldBridge.UnauthorizedRouter.selector);
        bridge.ccipReceive(message);
    }

    function test_RevertWhen_InvalidRecipient() public {
        uint256 amount = 1 ether;
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: BSC_TESTNET_SELECTOR,
            sender: REMOTE_CONTRACT,
            data: abi.encode(address(0), amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.prank(address(router));
        vm.expectRevert(IGoldBridge.InvalidRecipient.selector);
        bridge.ccipReceive(message);
    }

    function test_RevertWhen_InvalidAmount() public {
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: BSC_TESTNET_SELECTOR,
            sender: REMOTE_CONTRACT,
            data: abi.encode(bob, 0),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.prank(address(router));
        vm.expectRevert(IGoldBridge.InvalidAmount.selector);
        bridge.ccipReceive(message);
    }

    receive() external payable {}
}
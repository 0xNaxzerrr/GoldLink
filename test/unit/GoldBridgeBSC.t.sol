// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../../src/bridge/GoldBridgeBSC.sol";
import "../../src/tokens/GoldTokenBSC.sol";
import "../mocks/RouterMock.sol";
import "../mocks/LinkTokenMock.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";

contract GoldBridgeBSCTest is Test {
    GoldBridgeBSC public implementation;
    GoldBridgeBSC public bridge;
    GoldTokenBSC public token;
    RouterMock public router;
    LinkTokenMock public linkToken;

    // Paramètres de test
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    bytes remoteContract = hex"1234"; 
    uint64 sepoliaChainId = 16015286601757825753;
    address sourceAddress = makeAddr("sourceAddress");

    // Events
    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed chainSelector,
        address recipient,
        uint256 amount
    );
    event TokensBridged(address indexed recipient, uint256 amount);
    event RemoteContractSet(bytes remoteContract);
    event SepoliaChainIdSet(uint64 chainId);
    event AuthorizedSourceAddressSet(address sourceAddress);
    event FundsReceived(address sender, uint256 amount);

    function setUp() public {
        vm.warp(1000);
        console2.log("=== Debug Setup Start ===");

        // 1. Configuration initiale : on déploie les mocks
        router = new RouterMock();
        linkToken = new LinkTokenMock();
        token = new GoldTokenBSC();

        // 2. Déploie le bridge BSC sous forme de proxy UUPS
        implementation = new GoldBridgeBSC(
            address(router),
            address(token),
            address(linkToken),
            remoteContract,
            sepoliaChainId
        );

        bytes memory initData = abi.encodeWithSelector(GoldBridgeBSC.initialize.selector);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        bridge = GoldBridgeBSC(payable(address(proxy)));

        // 3. Configuration du bridge
        vm.startPrank(address(this));
        bridge.setSepoliaChainId(sepoliaChainId);
        bridge.setRemoteContract(remoteContract);
        token.setBridge(address(bridge));
        bridge.setAuthorizedSourceAddress(sourceAddress);
        vm.stopPrank();

        // 4. Prépare la balance de tokens d'alice
        vm.prank(address(bridge));
        token.bridgeMint(alice, 1000 ether);

        // 5. Setup les balances LINK et ETH
        linkToken.mint(alice, 100 ether);
        vm.deal(alice, 100 ether);
        
        // 6. Approvals
        vm.startPrank(alice);
        token.approve(address(bridge), type(uint256).max);
        linkToken.approve(address(bridge), type(uint256).max);
        vm.stopPrank();

        // 7. Configure le mock router
        router.setNextMessageId(bytes32(uint256(1)));
        router.setFees(0.01 ether);
    }

    // Tests du constructeur
    function testConstructor() public {
        GoldBridgeBSC newBridge = new GoldBridgeBSC(
            address(router),
            address(token),
            address(linkToken),
            remoteContract,
            sepoliaChainId
        );
        assertEq(address(router), newBridge.getRouter());
        assertEq(address(token), address(newBridge.goldToken()));
        assertEq(sepoliaChainId, newBridge.sepoliaChainId());
        assertEq(remoteContract, newBridge.remoteContractOnSepoliaChain());
    }

    function test_RevertWhen_InvalidConstructorParams() public {
        vm.expectRevert(IGoldBridgeBSC.InvalidRecipient.selector);
        new GoldBridgeBSC(
            address(router),
            address(0),
            address(linkToken),
            remoteContract,
            sepoliaChainId
        );

        vm.expectRevert(IGoldBridgeBSC.InvalidRecipient.selector);
        new GoldBridgeBSC(
            address(router),
            address(token),
            address(0),
            remoteContract,
            sepoliaChainId
        );
    }

    // Tests des fonctions principales
    function testInitialState() public {
        assertEq(address(router), bridge.getRouter());
        assertEq(address(token), address(bridge.goldToken()));
        assertEq(sepoliaChainId, bridge.sepoliaChainId());
        assertEq(remoteContract, bridge.remoteContractOnSepoliaChain());
        assertEq(sourceAddress, bridge.authorizedSourceAddress());
    }

    function testBridgeBack() public {
        uint256 amount = 100 ether;
        uint256 fees = 0.01 ether;
        uint256 initialTokenBalance = token.balanceOf(alice);
        uint256 initialLinkBalance = linkToken.balanceOf(alice);

        bytes32 expectedMessageId = bytes32(uint256(1));
        router.setNextMessageId(expectedMessageId);
        router.setFees(fees);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit MessageSent(expectedMessageId, sepoliaChainId, bob, amount);
        bridge.bridgeBack(bob, amount);

        assertEq(token.balanceOf(alice), initialTokenBalance - amount);
        assertEq(linkToken.balanceOf(alice), initialLinkBalance - fees);
        assertEq(linkToken.balanceOf(address(router)), fees);
    }

    function testCcipReceive() public {
        uint256 amount = 50 ether;
        uint256 initialBalance = token.balanceOf(bob);
        
        bytes memory encodedSourceAddr = abi.encode(sourceAddress);
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: sepoliaChainId,
            sender: encodedSourceAddr,
            data: abi.encode(bob, amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.prank(address(router));
        vm.expectEmit(true, true, true, true);
        emit TokensBridged(bob, amount);
        bridge.ccipReceive(message);

        assertEq(token.balanceOf(bob), initialBalance + amount);
    }
    // Tests des setters admin
    function testSetRemoteContract() public {
        bytes memory newContract = hex"5678";
        vm.prank(bridge.owner());
        vm.expectEmit(true, true, true, true);
        emit RemoteContractSet(newContract);
        bridge.setRemoteContract(newContract);
        assertEq(bridge.remoteContractOnSepoliaChain(), newContract);
    }

    function testSetSepoliaChainId() public {
        uint64 newChainId = 123456;
        vm.prank(bridge.owner());
        vm.expectEmit(true, true, true, true);
        emit SepoliaChainIdSet(newChainId);
        bridge.setSepoliaChainId(newChainId);
        assertEq(bridge.sepoliaChainId(), newChainId);
    }

    function testSetAuthorizedSourceAddress() public {
        address newSource = makeAddr("newSource");
        vm.prank(bridge.owner());
        vm.expectEmit(true, true, true, true);
        emit AuthorizedSourceAddressSet(newSource);
        bridge.setAuthorizedSourceAddress(newSource);
        assertEq(bridge.authorizedSourceAddress(), newSource);
    }

    function test_RevertWhen_InvalidSourceChain() public {
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: 9999999,
            sender: abi.encode(sourceAddress),
            data: abi.encode(bob, 50 ether),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.prank(address(router));
        vm.expectRevert(IGoldBridgeBSC.InvalidSourceChain.selector);
        bridge.ccipReceive(message);
    }

    function test_RevertWhen_InvalidSourceAddress() public {
        bytes memory badSource = abi.encode(makeAddr("untrusted"));
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: sepoliaChainId,
            sender: badSource,
            data: abi.encode(bob, 50 ether),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.prank(address(router));
        vm.expectRevert(IGoldBridgeBSC.InvalidSourceAddress.selector);
        bridge.ccipReceive(message);
    }

    function test_RevertWhen_InvalidRecipient() public {
        bytes memory encodedSourceAddr = abi.encode(sourceAddress);
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: sepoliaChainId,
            sender: encodedSourceAddr,
            data: abi.encode(address(0), 50 ether),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.prank(address(router));
        vm.expectRevert(IGoldBridgeBSC.InvalidRecipient.selector);
        bridge.ccipReceive(message);
    }

    function test_RevertWhen_InvalidAmount() public {
        bytes memory encodedSourceAddr = abi.encode(sourceAddress);
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: sepoliaChainId,
            sender: encodedSourceAddr,
            data: abi.encode(bob, 0),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.prank(address(router));
        vm.expectRevert(IGoldBridgeBSC.InvalidAmount.selector);
        bridge.ccipReceive(message);
    }

    function test_RevertWhen_BurnTooManyTokens() public {
        uint256 currentBalance = token.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert(IGoldBridgeBSC.InsufficientBalance.selector);
        bridge.bridgeBack(bob, currentBalance + 1 ether);
    }

    function test_RevertWhen_InsufficientFees() public {
        uint256 amount = 100 ether;
        uint256 tooHighFees = 1000 ether;
        router.setFees(tooHighFees);
        
        vm.prank(alice);
        vm.expectRevert(IGoldBridgeBSC.InsufficientFees.selector);
        bridge.bridgeBack(bob, amount);
    }

    function test_RevertWhen_UnauthorizedSetters() public {
        vm.startPrank(alice);
        
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        bridge.setAuthorizedSourceAddress(bob);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        bridge.setRemoteContract(hex"5678");

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        bridge.setSepoliaChainId(123456);
        
        vm.stopPrank();
    }

    function test_RevertWhen_SetInvalidSourceAddress() public {
        vm.prank(bridge.owner());
        vm.expectRevert(IGoldBridgeBSC.InvalidRecipient.selector);
        bridge.setAuthorizedSourceAddress(address(0));
    }

    receive() external payable {}
}
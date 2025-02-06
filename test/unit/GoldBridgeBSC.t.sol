// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/bridge/GoldBridgeBSC.sol";
import "../../src/tokens/GoldTokenBSC.sol";
import "../mocks/RouterMock.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";

contract GoldBridgeBSCTest is Test {
    GoldBridgeBSC public implementation;
    GoldBridgeBSC public bridge;
    GoldTokenBSC public token;
    RouterMock public router;

    // Paramètres de test
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    bytes remoteContract = hex"1234"; // Format hexadécimal correct
    uint64 sepoliaChainId = 16015286601757825753;
    address sourceAddress = makeAddr("sourceAddress");

    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed chainSelector,
        address recipient,
        uint256 amount
    );
    event TokensBridged(address indexed recipient, uint256 amount);

    function setUp() public {
        // 1. Configuration initiale
        router = new RouterMock();
        token = new GoldTokenBSC();

        // 2. Configuration du bridge 
        implementation = new GoldBridgeBSC(
            address(router),
            address(token),
            remoteContract,
            sepoliaChainId
        );

        bytes memory initData = abi.encodeWithSelector(GoldBridgeBSC.initialize.selector);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        bridge = GoldBridgeBSC(payable(address(proxy)));

        // 3. Configuration avec le bon ordre
        vm.startPrank(address(this));
        bridge.setSepoliaChainId(sepoliaChainId);
        bridge.setRemoteContract(remoteContract); // Ajout de cette ligne
        token.setBridge(address(bridge));
        bridge.setAuthorizedSourceAddress(sourceAddress);
        vm.stopPrank();

        // 4. Setup des tokens
        vm.prank(address(bridge));
        token.bridgeMint(alice, 1000 ether);

        vm.deal(address(bridge), 100 ether);
        vm.prank(alice);
        token.approve(address(bridge), type(uint256).max);
    }

    function testInitialState() public view {
        assertEq(bridge.getRouter(), address(router));
        assertEq(address(bridge.goldToken()), address(token));
        assertEq(bridge.sepoliaChainId(), sepoliaChainId);
        
        // Vérification bytes pour remoteContract
        bytes memory storedContract = bridge.remoteContractOnSepoliaChain();
        assertEq(storedContract, remoteContract);
        
        assertEq(bridge.authorizedSourceAddress(), sourceAddress);
    }

    function testBridgeBack() public {
        uint256 amount = 100 ether;
        uint256 initialBalance = token.balanceOf(alice);

        vm.prank(alice);
        // Correction de l'event avec le bon chainId
        emit MessageSent(bytes32(0), sepoliaChainId, bob, amount);
        bridge.bridgeBack(bob, amount);

        assertEq(token.balanceOf(alice), initialBalance - amount);
    }

    function testCcipReceive() public {
        uint256 amount = 50 ether;
        
        // Création du message CCIP avec le bon format
        bytes memory encodedSourceAddr = abi.encode(sourceAddress);
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: sepoliaChainId, // Utilisation du bon chainId
            sender: encodedSourceAddr,           // Encodage correct de l'adresse source
            data: abi.encode(bob, amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        // Test de réception
        vm.startPrank(address(router));
        bridge.ccipReceive(message); // L'event sera émis par le contrat
        vm.stopPrank();

        assertEq(token.balanceOf(bob), amount);
    }

    function testSetAuthorizedSourceAddress() public {
        address newSource = makeAddr("newSource");
        vm.prank(bridge.owner());
        bridge.setAuthorizedSourceAddress(newSource);
        assertEq(bridge.authorizedSourceAddress(), newSource);
    }

    function test_RevertWhen_UnauthorizedCcipReceive() public {
        Client.Any2EVMMessage memory message;
        vm.prank(alice);
        vm.expectRevert();
        bridge.ccipReceive(message);
    }

    function test_RevertWhen_InvalidSourceChain() public {
        uint256 amount = 50 ether;
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: 123, // Invalid chain ID
            sender: abi.encode(sourceAddress),
            data: abi.encode(bob, amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        vm.prank(address(router));
        vm.expectRevert();
        bridge.ccipReceive(message);
    }

    receive() external payable {}
}
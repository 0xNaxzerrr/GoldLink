// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../../src/bridge/GoldBridge.sol";
import "../../src/bridge/GoldBridgeBSC.sol";
import "../../src/tokens/GoldToken.sol";
import "../../src/tokens/GoldTokenBSC.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@chainlink/contracts/ccip/interfaces/IRouterClient.sol";
import "@chainlink/contracts/shared/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/ccip/libraries/Client.sol";

contract BridgeIntegrationTest is Test {
    GoldBridge public sepoliaBridge;
    GoldBridgeBSC public bscBridge;
    GoldToken public sepoliaToken;
    GoldTokenBSC public bscToken;

    address constant SEPOLIA_ROUTER = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address constant BSC_ROUTER = 0xE1053aE1857476f36A3C62580FF9b016E8EE8F6f;
    address constant LINK_SEPOLIA = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant LINK_BSC = 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06;
    address constant XAU_USD_FEED = 0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea;
    address constant ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    
    uint64 constant BSC_CHAIN = 13264668187771770619;
    uint64 constant SEPOLIA_CHAIN = 16015286601757825753;

    address deployer;
    address user;
    uint256 sepoliaFork;
    uint256 bscFork;

    function setUp() public {
        deployer = makeAddr("deployer");
        user = makeAddr("user");
        vm.deal(deployer, 100 ether);
        vm.deal(user, 100 ether);
        
        // Fork Sepolia
        sepoliaFork = vm.createFork(vm.envString("RPC_URL_SEPOLIA"));
        vm.selectFork(sepoliaFork);
        
        vm.startPrank(deployer);
        
        // Deploy et setup Sepolia
        sepoliaToken = new GoldToken(XAU_USD_FEED, ETH_USD_FEED, payable(deployer));
        sepoliaToken.initialize();

        GoldBridge impl = new GoldBridge(
            SEPOLIA_ROUTER,
            address(sepoliaToken),
            LINK_SEPOLIA,
            "",
            BSC_CHAIN
        );
        
        bytes memory initData = abi.encodeCall(GoldBridge.initialize, ());
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        sepoliaBridge = GoldBridge(address(proxy));
        sepoliaToken.setBridgeAddress(address(sepoliaBridge));
        
        vm.stopPrank();

        // Fork BSC
        bscFork = vm.createFork(vm.envString("RPC_URL_BSC_TESTNET"));
        vm.selectFork(bscFork);
        
        vm.startPrank(deployer);
        
        // Deploy et setup BSC
        bscToken = new GoldTokenBSC();
        GoldBridgeBSC bscImpl = new GoldBridgeBSC(
            BSC_ROUTER,
            address(bscToken),
            LINK_BSC,
            "",
            SEPOLIA_CHAIN
        );
        
        bytes memory bscInitData = abi.encodeCall(GoldBridgeBSC.initialize, ());
        ERC1967Proxy bscProxy = new ERC1967Proxy(address(bscImpl), bscInitData);
        bscBridge = GoldBridgeBSC(address(bscProxy));
        bscToken.setBridge(address(bscBridge));
        
        vm.stopPrank();

        // Configuration des bridges
        _configureBridges();

        // Setup LINK tokens pour les tests
        vm.selectFork(sepoliaFork);
        deal(LINK_SEPOLIA, user, 100 ether);
        
        vm.selectFork(bscFork);
        deal(LINK_BSC, user, 100 ether);
    }

    function testBridgeOutAndBack() public {
        uint256 amount = 1 ether;
        
        // Test Sepolia -> BSC
        vm.selectFork(sepoliaFork);
        
        // Mint initial tokens avec adminMint
        vm.startPrank(deployer);
        sepoliaToken.adminMint(user, amount);
        vm.stopPrank();
        
        vm.startPrank(user);
        uint256 initialBalance = sepoliaToken.balanceOf(user);
        sepoliaToken.approve(address(sepoliaBridge), amount);
        LinkTokenInterface(LINK_SEPOLIA).approve(address(sepoliaBridge), 1 ether);
        
        // Mock des appels CCIP
        vm.mockCall(
            SEPOLIA_ROUTER,
            abi.encodeWithSelector(IRouterClient.getFee.selector),
            abi.encode(0.1 ether)
        );

        vm.mockCall(
            SEPOLIA_ROUTER,
            abi.encodeWithSelector(IRouterClient.ccipSend.selector),
            abi.encode(bytes32(uint256(1)))
        );

        // Bridge out
        sepoliaBridge.bridgeOut(user, amount);
        assertEq(sepoliaToken.balanceOf(user), initialBalance - amount);
        vm.stopPrank();

        // Simulate CCIP message sur BSC
        vm.selectFork(bscFork);
        vm.startPrank(BSC_ROUTER);
        
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(uint256(1)),
            sourceChainSelector: SEPOLIA_CHAIN,
            sender: abi.encode(address(sepoliaBridge)),
            data: abi.encode(user, amount),
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });
        
        bscBridge.ccipReceive(message);
        assertEq(bscToken.balanceOf(user), amount);
        vm.stopPrank();
    }

    function _configureBridges() private {
        vm.startPrank(deployer);
        
        // Configure Sepolia bridge
        vm.selectFork(sepoliaFork);
        sepoliaBridge.setRemoteContract(abi.encodePacked(address(bscBridge)));
        sepoliaBridge.setDestinationChainId(BSC_CHAIN);
        
        // Configure BSC bridge
        vm.selectFork(bscFork);
        bscBridge.setRemoteContract(abi.encodePacked(address(sepoliaBridge)));
        bscBridge.setSepoliaChainId(SEPOLIA_CHAIN);
        bscBridge.setAuthorizedSourceAddress(address(sepoliaBridge));
        
        vm.stopPrank();
    }

    receive() external payable {}
}
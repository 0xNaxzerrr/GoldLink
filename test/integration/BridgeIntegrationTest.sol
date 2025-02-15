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

contract BridgeIntegrationTest is Test {
    GoldBridge public sepoliaBridge;
    GoldBridgeBSC public bscBridge;
    GoldToken public sepoliaToken;
    GoldTokenBSC public bscToken;
    LinkTokenInterface public linkToken;

    address constant SEPOLIA_ROUTER = 0xD0daae2231E9CB96b94C8512223533293C3693Bf;
    address constant BSC_ROUTER = 0x9527E2d01A3064ef6b50c1Da1C0cC523803BCFF2;
    address constant LINK_SEPOLIA = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant LINK_BSC = 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06;
    
    uint64 constant BSC_CHAIN = 13264668187771770619;
    uint64 constant SEPOLIA_CHAIN = 16015286601757825753;

    address constant SEPOLIA_XAU_USD = 0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea;
    address constant SEPOLIA_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    address deployer;
    address user;
    uint256 sepoliaFork;
    uint256 bscFork;

    function setUp() public {
        deployer = makeAddr("deployer");
        user = makeAddr("user");
        
        // Setup Sepolia
        sepoliaFork = vm.createFork(vm.envString("RPC_URL_SEPOLIA"));
        vm.selectFork(sepoliaFork);
        
        vm.startPrank(deployer);
        
        // Deploy Sepolia contracts
        sepoliaToken = new GoldToken(SEPOLIA_XAU_USD, SEPOLIA_ETH_USD, payable(deployer));
        sepoliaToken.initialize();

        GoldBridge impl = new GoldBridge(SEPOLIA_ROUTER, address(sepoliaToken), LINK_SEPOLIA, "", BSC_CHAIN);
        bytes memory initData = abi.encodeWithSelector(GoldBridge.initialize.selector);
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        sepoliaBridge = GoldBridge(payable(address(proxy)));
        sepoliaToken.setBridgeAddress(address(sepoliaBridge));
        
        // Setup BSC
        bscFork = vm.createFork(vm.envString("RPC_URL_BSC_TESTNET"));
        vm.selectFork(bscFork);
        
        // Deploy BSC contracts
        bscToken = new GoldTokenBSC();
        GoldBridgeBSC bscImpl = new GoldBridgeBSC(BSC_ROUTER, address(bscToken), LINK_BSC, "", SEPOLIA_CHAIN);
        bytes memory bscInitData = abi.encodeWithSelector(GoldBridgeBSC.initialize.selector);
        ERC1967Proxy bscProxy = new ERC1967Proxy(address(bscImpl), bscInitData);
        bscBridge = GoldBridgeBSC(payable(address(bscProxy)));
        bscToken.setBridge(address(bscBridge));

        // Link contracts
        bytes memory sepoliaBridgeAddr = abi.encodePacked(address(sepoliaBridge));
        bytes memory bscBridgeAddr = abi.encodePacked(address(bscBridge));
        
        vm.selectFork(sepoliaFork);
        sepoliaBridge.setRemoteContract(bscBridgeAddr);
        
        vm.selectFork(bscFork);
        bscBridge.setRemoteContract(sepoliaBridgeAddr);
        bscBridge.setAuthorizedSourceAddress(address(sepoliaBridge));
        
        vm.stopPrank();
    }

    function testSimpleBridgeOut() public {
        uint256 amount = 1 ether;
        uint256 fees = 0.1 ether;
        
        console2.log("Starting test with amount:", amount);
        console2.log("BSC Chain ID:", BSC_CHAIN);
        
        vm.selectFork(sepoliaFork);
        
        // Mint initial tokens
        vm.startPrank(address(sepoliaBridge));
        sepoliaToken.bridgeMint(user, amount);
        vm.stopPrank();
        
        vm.startPrank(user);
        sepoliaToken.approve(address(sepoliaBridge), amount);

        // Mock CCIP calls
        _mockCCIPCalls(SEPOLIA_ROUTER, LINK_SEPOLIA, BSC_CHAIN, fees);

        // Execute bridge
        sepoliaBridge.bridgeOut(user, amount);
        vm.stopPrank();

        // Verify on BSC
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
        vm.stopPrank();
        
        assertEq(bscToken.balanceOf(user), amount, "Token not bridged correctly");
    }

    function _mockCCIPCalls(address router, address linkToken, uint64 destChain, uint256 fees) internal {
        // 1. Prépare le message exact que le contrat va envoyer
        bytes memory remoteContract = sepoliaBridge.remoteContractOnDestinationChain();
        
        // Construction du message identique au contrat
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: remoteContract,
            data: abi.encode(user, amount), // Utilise les mêmes paramètres que bridgeOut
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 200000})
            ),
            feeToken: linkToken
        });

        // 2. Mock dans l'ordre exact des appels
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IRouterClient.isChainSupported.selector,
                destChain
            ),
            abi.encode(true)
        );

        // 3. Mock getFee avec le message exact
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IRouterClient.getFee.selector,
                destChain,
                message // Utilise le même message que le contrat
            ),
            abi.encode(fees)
        );

        // 4. Mock les approbations LINK
        vm.mockCall(
            linkToken,
            abi.encodeWithSelector(
                LinkTokenInterface.balanceOf.selector,
                address(sepoliaBridge)
            ),
            abi.encode(fees)
        );

        vm.mockCall(
            linkToken,
            abi.encodeWithSelector(
                LinkTokenInterface.approve.selector,
                router,
                fees
            ),
            abi.encode(true)
        );

        // 5. Mock ccipSend avec le message exact
        vm.mockCall(
            router,
            abi.encodeWithSelector(
                IRouterClient.ccipSend.selector,
                destChain,
                message
            ),
            abi.encode(bytes32(uint256(1)))
        );
    }

    receive() external payable {}
}
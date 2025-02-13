// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/bridge/GoldBridge.sol";
import "../src/bridge/GoldBridgeBSC.sol";
import "../src/tokens/GoldToken.sol";
import "../src/tokens/GoldTokenBSC.sol";
import "@chainlink/contracts/shared/interfaces/LinkTokenInterface.sol";

contract ConfigureBridges is Script {
    address public goldBridgeSepolia;
    address public goldBridgeBSC;
    address public goldTokenBSC;
    address public linkSepolia;
    address public linkBSC;
    uint64 public destinationChainId;
    uint64 public sepoliaChainId;

    function setUp() public {
        goldBridgeSepolia = vm.envAddress("GOLD_BRIDGE_SEPOLIA");
        goldBridgeBSC = vm.envAddress("GOLD_BRIDGE_BSC");
        goldTokenBSC = vm.envAddress("GOLD_TOKEN_BSC");
        linkSepolia = vm.envAddress("LINK_SEPOLIA");
        linkBSC = vm.envAddress("BSC_LINK");
        destinationChainId = uint64(vm.envUint("DESTINATION_CHAIN_ID"));
        sepoliaChainId = uint64(vm.envUint("SEPOLIA_CHAIN_ID"));
    }

    function run() external {
        if (block.chainid == 97) { 
            configureBSCBridge();
        } else if (block.chainid == 11155111) { 
            configureSepoliaBridge();
        } else {
            revert("Unknown network");
        }
    }

    function configureSepoliaBridge() internal {
        console2.log("\n=== Configuration Sepolia ===");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address goldTokenSepolia = vm.envAddress("GOLD_TOKEN_SEPOLIA");

        vm.startBroadcast(deployerPrivateKey);

        GoldBridge sepoliaBridge = GoldBridge(payable(goldBridgeSepolia));
        console2.log("Deployer address:", deployer);
        console2.log("Bridge owner:", sepoliaBridge.owner());
        
        try sepoliaBridge.initialize() {
            console2.log("Bridge initialized");
        } catch {
            console2.log("Bridge already initialized");
        }

        sepoliaBridge.setRemoteContract(abi.encodePacked(goldBridgeBSC));
        sepoliaBridge.setDestinationChainId(destinationChainId);

        LinkTokenInterface linkToken = LinkTokenInterface(linkSepolia);
        linkToken.approve(goldBridgeSepolia, type(uint256).max);
        console2.log("LINK approval set successfully");

        GoldToken goldToken = GoldToken(goldTokenSepolia);
        goldToken.approve(goldBridgeSepolia, type(uint256).max);
        console2.log("GOLD token approval set successfully");

        vm.stopBroadcast();
    }

    function configureBSCBridge() internal {
        console2.log("\n=== Configuration BSC Testnet ===");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        GoldBridgeBSC bscBridge = GoldBridgeBSC(payable(goldBridgeBSC));
        console2.log("Deployer address:", deployer);
        
        try bscBridge.initialize() {
            console2.log("BSC Bridge initialized");
        } catch {
            console2.log("BSC Bridge already initialized");
        }

        bscBridge.setAuthorizedSourceAddress(goldBridgeSepolia);
        console2.log("Source address set successfully");

        bytes memory remoteContract = abi.encode("f(address)", goldBridgeSepolia);
        bscBridge.setRemoteContract(remoteContract);
        console2.log("Remote contract set successfully");

        bscBridge.setSepoliaChainId(sepoliaChainId);
        console2.log("Sepolia chain ID set successfully");

        GoldTokenBSC token = GoldTokenBSC(goldTokenBSC);
        token.setBridge(goldBridgeBSC);
        console2.log("Bridge set on token successfully");

        LinkTokenInterface linkTokenBSC = LinkTokenInterface(linkBSC);
        linkTokenBSC.approve(goldBridgeBSC, type(uint256).max);
        console2.log("LINK approval set successfully");

        token.approve(goldBridgeBSC, type(uint256).max);
        console2.log("GOLD BSC token approval set successfully");

        console2.log("\n=== Configuration completed successfully ===");
        vm.stopBroadcast();
    }
}
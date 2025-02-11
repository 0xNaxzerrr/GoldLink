// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/tokens/GoldTokenBSC.sol";
import "../src/bridge/GoldBridgeBSC.sol";

contract DeployBSCContracts is Script {
    // Adresses BSC Testnet
    address constant BSC_ROUTER = 0xE1053aE1857476f36A3C62580FF9b016E8EE8F6f;
    address constant BSC_LINK = 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06;
    uint64 constant SEPOLIA_CHAIN_ID = 16015286601757825753;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        GoldTokenBSC goldTokenBSC = new GoldTokenBSC();

        GoldBridgeBSC goldBridgeBSC = new GoldBridgeBSC(
            BSC_ROUTER,
            address(goldTokenBSC),
            BSC_LINK,                 
            abi.encodePacked(address(0)),
            SEPOLIA_CHAIN_ID
        );

        goldBridgeBSC.initialize();
        goldTokenBSC.setBridge(address(goldBridgeBSC));

        console.log("Deployed on BSC Testnet:");
        console.log("Token:", address(goldTokenBSC));
        console.log("Bridge:", address(goldBridgeBSC));
        console.log("Router:", BSC_ROUTER);
        console.log("LINK:", BSC_LINK);

        vm.stopBroadcast();
    }
}
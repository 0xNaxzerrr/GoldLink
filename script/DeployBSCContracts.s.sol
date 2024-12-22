// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/GoldTokenBSC.sol";
import "../src/GoldBridgeBSC.sol";

contract DeployBSCContracts is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address bscRouter = 0xE1053aE1857476f36A3C62580FF9b016E8EE8F6f;

        GoldTokenBSC goldTokenBSC = new GoldTokenBSC(address(0));

        GoldBridgeBSC goldBridgeBSC = new GoldBridgeBSC(
            bscRouter,
            address(goldTokenBSC),
            abi.encodePacked(address(0)),
            13264668187771770619
        );

        goldTokenBSC.setBridge(address(goldBridgeBSC));

        console.log("BSC - GoldTokenBSC deployed at:", address(goldTokenBSC));
        console.log("BSC - GoldBridgeBSC deployed at:", address(goldBridgeBSC));

        vm.stopBroadcast();
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/GoldTokenBSC.sol";
import "../src/GoldBridgeBSC.sol";

contract DeployBSCContracts is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address bscRouter = 0x9527E2d01A3064ef6b50c1Da1C0cC523803BCFF2;

        GoldTokenBSC goldTokenBSC = new GoldTokenBSC(address(0));

        GoldBridgeBSC goldBridgeBSC = new GoldBridgeBSC(
            bscRouter,
            address(goldTokenBSC),
            abi.encodePacked(address(0)),
            16015286601757825753
        );

        goldTokenBSC.setBridge(address(goldBridgeBSC));

        console.log("BSC - GoldTokenBSC deployed at:", address(goldTokenBSC));
        console.log("BSC - GoldBridgeBSC deployed at:", address(goldBridgeBSC));

        vm.stopBroadcast();
    }
}
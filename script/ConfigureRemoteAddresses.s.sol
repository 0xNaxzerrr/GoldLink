// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/GoldBridge.sol";
import "../src/GoldBridgeBSC.sol";

contract ConfigureRemoteAddresses is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address sepoliaBridge = 0xbD3D66AE432d0F8C985E1791cD3b92403F35ebCc; 
        address bscBridge = 0xB1081244C17317163Bed920665e54b3D017f92C8; 

        GoldBridge(payable(sepoliaBridge)).setRemoteContract(abi.encodePacked(bscBridge));
        GoldBridgeBSC(payable(bscBridge)).setRemoteContract(abi.encodePacked(sepoliaBridge));

        console.log("Remote addresses configured successfully");

        vm.stopBroadcast();
    }
}
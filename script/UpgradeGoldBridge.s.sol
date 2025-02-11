// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import "forge-std/Script.sol";
// import "forge-std/console2.sol";
// import "../src/bridge/GoldBridge.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// contract UpgradeGoldBridge is Script {
//     address constant PROXY_ADDRESS = 0xED7c3Db31968B6655dFF00fc17d03400D172e889;
//     function run() external {
//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         vm.startBroadcast(deployerPrivateKey);

//         // 1. Déploie la nouvelle implémentation
//         GoldBridge newImplementation = new GoldBridge(
//             0x0bf3de8c5d3e8a2b34d2beef1bc6582c4f6d9db6,
//             0x669120365b50362392a920f914Af459Dd6e824B9,
//             0x779877A7B0D9E8603169DdbD7836e478b4624789,
//             0x15ccd345a828113104e48aef6f63f4d7ac4da2ae,
//             16015286601757825753
//         );

//         // 2. Fais l'upgrade vers la nouvelle implémentation
//         GoldBridge proxy = GoldBridge(PROXY_ADDRESS);
//         proxy.upgradeTo(address(newImplementation));

//         console2.log("Bridge upgraded to:", address(newImplementation));

//         vm.stopBroadcast();
//     }
// }
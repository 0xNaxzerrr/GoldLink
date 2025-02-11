// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import "forge-std/Script.sol";
// import "forge-std/console2.sol";

// // Importation des contrats à configurer
// import "../src/bridge/GoldBridge.sol";
// import "../src/bridge/GoldBridgeBSC.sol";
// import "../src/tokens/GoldToken.sol";
// import "../src/tokens/GoldTokenBSC.sol";
// import "@chainlink/contracts/shared/interfaces/LinkTokenInterface.sol";

// contract ConfigureBridges is Script {
//     // Fonction helper pour loguer les informations d'un bridge dans un bloc séparé
//     function _logBridgeDetails(
//         string memory network,
//         bytes memory remoteData,
//         uint64 chainId,
//         uint256 linkBalance
//     ) internal {
//         console2.log(string(abi.encodePacked(network, " Bridge Remote:")), string(remoteData));
//         console2.log(string(abi.encodePacked(network, " Bridge Chain ID:")), chainId);
//         console2.log(string(abi.encodePacked(network, " LINK balance:")), linkBalance);
//     }

//     function run() external {
//         // ============================================================
//         // Configuration côté Sepolia
//         // ============================================================
//         console2.log("=== Configuration Sepolia ===");
//         // Récupération des variables d'environnement pour Sepolia
//         string memory rpcSepolia = vm.envString("RPC_URL_SEPOLIA");
//         uint256 forkSepolia = vm.createFork(rpcSepolia);
//         vm.selectFork(forkSepolia);

//         address goldBridgeSepolia = vm.envAddress("GOLD_BRIDGE_SEPOLIA");
//         address goldBridgeBSC = vm.envAddress("GOLD_BRIDGE_BSC");
//         address goldTokenSepolia = vm.envAddress("GOLD_TOKEN_SEPOLIA");
//         uint64 destinationChainId = uint64(vm.envUint("DESTINATION_CHAIN_ID"));
//         uint256 depositLinkAmountSepolia = vm.envUint("DEPOSIT_LINK_AMOUNT_SEPOLIA");

//         // Récupération de la clé privée et de l'adresse du déployeur sur Sepolia
//         uint256 pk = uint256(vm.envBytes32("PRIVATE_KEY"));
//         address deployerSepolia = vm.addr(pk);
//         console2.log("Sepolia deployer:", deployerSepolia);

//         // Vérification de la propriété sur les contrats de pont et token
//         GoldBridge sepoliaBridge = GoldBridge(payable(goldBridgeSepolia));
//         require(sepoliaBridge.owner() == deployerSepolia, "Sepolia: Not bridge owner");
//         GoldToken tokenSepolia = GoldToken(goldTokenSepolia);
//         require(tokenSepolia.owner() == deployerSepolia, "Sepolia: Not token owner");

//         vm.startBroadcast(pk);

//         // Configuration du pont Sepolia
//         sepoliaBridge.setRemoteContract(abi.encodePacked(goldBridgeBSC));
//         console2.log("[OK] Remote contract set to:", goldBridgeBSC);

//         sepoliaBridge.setDestinationChainId(destinationChainId);
//         console2.log("[OK] Destination chain ID set to:", destinationChainId);

//         // Approbations
//         // Adresse LINK sur Sepolia (fixe d'après Chainlink)
//         address linkSepolia = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
//         LinkTokenInterface linkTokenSepolia = LinkTokenInterface(linkSepolia);
//         linkTokenSepolia.approve(goldBridgeSepolia, type(uint256).max);
//         console2.log("[OK] LINK approved for bridge");

//         tokenSepolia.approve(goldBridgeSepolia, type(uint256).max);
//         console2.log("[OK] Token approved for bridge");

//         // Dépôt de LINK sur le pont (si nécessaire)
//         uint256 currentLinkBalanceSepolia = linkTokenSepolia.balanceOf(address(sepoliaBridge));
//         if (depositLinkAmountSepolia > 0 && currentLinkBalanceSepolia < depositLinkAmountSepolia) {
//             sepoliaBridge.depositLink(depositLinkAmountSepolia);
//             console2.log("[OK] Deposited", depositLinkAmountSepolia, "LINK on Sepolia bridge");
//         }
//         vm.stopBroadcast();

//         // ============================================================
//         // Configuration côté BSC Testnet
//         // ============================================================
//         console2.log("\n=== Configuration BSC ===");
//         string memory rpcBSC = vm.envString("RPC_URL_BSC_TESTNET");
//         uint256 forkBSC = vm.createFork(rpcBSC);
//         vm.selectFork(forkBSC);

//         address goldBridgeBSCAddr = vm.envAddress("GOLD_BRIDGE_BSC");
//         address goldBridgeSepoliaAddr = vm.envAddress("GOLD_BRIDGE_SEPOLIA"); // réutilisé
//         address goldTokenBSCAddr = vm.envAddress("GOLD_TOKEN_BSC");
//         uint64 sepoliaChainId = uint64(vm.envUint("SEPOLIA_CHAIN_ID"));
//         uint256 depositLinkAmountBSC = vm.envUint("DEPOSIT_LINK_AMOUNT_BSC");

//         // Récupération de la clé privée pour BSC
//         uint256 pk2 = uint256(vm.envBytes32("PRIVATE_KEY2"));
//         address deployerBSC = vm.addr(pk2);
//         console2.log("BSC deployer:", deployerBSC);

//         // Vérification de la propriété sur le pont BSC
//         GoldBridgeBSC bscBridge = GoldBridgeBSC(payable(goldBridgeBSCAddr));
//         require(bscBridge.owner() == deployerBSC, "BSC: Not bridge owner");

//         vm.startBroadcast(pk2);

//         // Configuration du pont BSC
//         bscBridge.setRemoteContract(abi.encodePacked(goldBridgeSepoliaAddr));
//         console2.log("[OK] Remote contract set to:", goldBridgeSepoliaAddr);

//         bscBridge.setSepoliaChainId(sepoliaChainId);
//         console2.log("[OK] Sepolia chain ID set to:", sepoliaChainId);

//         bscBridge.setAuthorizedSourceAddress(goldBridgeSepoliaAddr);
//         console2.log("[OK] Authorized source set to:", goldBridgeSepoliaAddr);

//         // Configuration du token BSC pour qu'il reconnaisse le pont
//         GoldTokenBSC tokenBSC = GoldTokenBSC(goldTokenBSCAddr);
//         tokenBSC.setBridge(goldBridgeBSCAddr);
//         console2.log("[OK] Token bridge set on BSC token");

//         // Dépôt de LINK sur le pont BSC par transfert direct :
//         // L'adresse du LINK sur BSC doit être définie dans l'env sous la variable "BSC_LINK"
//         address linkBSC = vm.envAddress("BSC_LINK");
//         LinkTokenInterface linkTokenBSC = LinkTokenInterface(linkBSC);
//         // Approve le pont pour transférer le montant maximal (au cas où)
//         linkTokenBSC.approve(goldBridgeBSCAddr, type(uint256).max);
//         bool transferSuccess = linkTokenBSC.transferFrom(deployerBSC, address(bscBridge), depositLinkAmountBSC);
//         require(transferSuccess, "BSC: LINK transfer failed");
//         console2.log("[OK] Deposited", depositLinkAmountBSC, "LINK on BSC bridge");

//         vm.stopBroadcast();

//         // ============================================================
//         // Vérifications finales (via helper)
//         // ============================================================
//         console2.log("\n=== Final Verifications ===");
//         _logBridgeDetails("Sepolia", sepoliaBridge.remoteContractOnDestinationChain(), sepoliaBridge.destinationChainId(), linkTokenSepolia.balanceOf(address(sepoliaBridge)));
//         _logBridgeDetails("BSC", bscBridge.remoteContractOnSepoliaChain(), bscBridge.sepoliaChainId(), linkTokenBSC.balanceOf(address(bscBridge)));
//     }

//     // Fonction helper pour loguer les détails d'un bridge sans "Stack too deep"
//     function _logBridgeDetails(
//         string memory network,
//         bytes memory remoteData,
//         uint64 chainId,
//         uint256 linkBalance
//     ) internal {
//         console2.log(string(abi.encodePacked(network, " Bridge Remote:")), string(remoteData));
//         console2.log(string(abi.encodePacked(network, " Bridge Chain ID:")), chainId);
//         console2.log(string(abi.encodePacked(network, " LINK balance:")), linkBalance);
//     }
// }

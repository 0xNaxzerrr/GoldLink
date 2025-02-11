// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/lottery/GoldLottery.sol";
import "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import "@chainlink/contracts/shared/interfaces/LinkTokenInterface.sol";

contract DeployVRFLottery is Script {
    // Adresses Sepolia pour Chainlink VRF V2.5
    address constant VRF_COORDINATOR =
        0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    address constant LINK_TOKEN = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    // Paramètres VRF
    bytes32 constant KEY_HASH =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 constant CALLBACK_GAS_LIMIT = 2_500_000;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint256 constant FUND_AMOUNT = 2 ether; // 2 LINK

    function run() external {
        // Récupérer la clé privée du déployeur
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Afficher les informations de déploiement
        console2.log("Deploying VRF Lottery");
        console2.log("Deployer Address:", deployer);
        console2.log("Deployer Balance:", deployer.balance);

        // Vérifier le solde LINK
        uint256 linkBalance = LinkTokenInterface(LINK_TOKEN).balanceOf(
            deployer
        );
        console2.log("LINK Balance:", linkBalance);

        // Commencer le déploiement
        vm.startBroadcast(deployerPrivateKey);

        // Créer un abonnement VRF
        uint256 subId = IVRFCoordinatorV2Plus(VRF_COORDINATOR)
            .createSubscription();
        console2.log("Created VRF Subscription ID:", subId);

        // Financer l'abonnement
        LinkTokenInterface(LINK_TOKEN).transferAndCall(
            VRF_COORDINATOR,
            FUND_AMOUNT,
            abi.encode(subId)
        );
        console2.log("Funded Subscription with LINK");

        // Déployer le contrat de loterie
        GoldLottery goldLottery = new GoldLottery(
            VRF_COORDINATOR,
            KEY_HASH,
            subId,
            CALLBACK_GAS_LIMIT,
            REQUEST_CONFIRMATIONS
        );
        console2.log("Deployed Lottery Address:", address(goldLottery));

        // Ajouter le contrat de loterie comme consommateur
        IVRFCoordinatorV2Plus(VRF_COORDINATOR).addConsumer(
            subId,
            address(goldLottery)
        );
        console2.log("Added Lottery as VRF Consumer");

        // Vérifier les détails de l'abonnement
        (
            uint96 balance,
            uint96 nativeBalance,
            uint64 reqCount,
            address owner,
            address[] memory consumers
        ) = IVRFCoordinatorV2Plus(VRF_COORDINATOR).getSubscription(subId);

        console2.log("Subscription Details:");
        console2.log("LINK Balance:", balance);
        console2.log("Native Balance:", nativeBalance);
        console2.log("Request Count:", reqCount);
        console2.log("Owner:", owner);
        console2.log("Consumer Count:", consumers.length);

        vm.stopBroadcast();
    }
}

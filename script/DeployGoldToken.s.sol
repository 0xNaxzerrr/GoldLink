// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/GoldToken.sol";
import "../src/GoldLottery.sol";

contract DeployGoldToken is Script {
    function run() external {
        // Charger la clé privée depuis .env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Commencer la transaction
        vm.startBroadcast(deployerPrivateKey);

        // Déployer le contrat GoldLottery
        GoldLottery goldLottery = new GoldLottery(1); // Pass subscription ID

        // Déployer le contrat GoldToken
        GoldToken goldToken = new GoldToken(
            0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea, // Adresse du price feed Chainlink
            payable(address(goldLottery)) // Adresse de GoldLottery
        );

        // Afficher les adresses des contrats déployés
        console.log("GoldLottery deployed at:", address(goldLottery));
        console.log("GoldToken deployed at:", address(goldToken));

        // Terminer la transaction
        vm.stopBroadcast();
    }
}

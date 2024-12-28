// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/GoldToken.sol";
import "../src/GoldLottery.sol";
import "../src/MockPriceFeed.sol";

contract DeployGoldToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Déployer le MockPriceFeed
        MockPriceFeed mockPriceFeed = new MockPriceFeed(2000 * 10 ** 8); // $2000 par ETH

        // Déployer GoldLottery
        GoldLottery goldLottery = new GoldLottery(
            49224907127232505730104472195340970228059491637583329608997101105052895073023
        );

        // Déployer GoldToken
        GoldToken goldToken = new GoldToken(
            address(mockPriceFeed), // Adresse du MockPriceFeed
            payable(address(goldLottery)) // Adresse de GoldLottery
        );

        console.log("MockPriceFeed deployed at:", address(mockPriceFeed));
        console.log("GoldLottery deployed at:", address(goldLottery));
        console.log("GoldToken deployed at:", address(goldToken));

        vm.stopBroadcast();
    }
}

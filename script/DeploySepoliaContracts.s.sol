// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/bridge/GoldBridge.sol";
import "../src/tokens/GoldToken.sol";

contract DeploySepoliaContracts is Script {
    address constant sepoliaRouter = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address constant xauUsdFeed = 0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea;
    address constant ethUsdFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address constant LOTTERY_ADDRESS = 0xC665024dcBAACF27AFfa62eb0F968D81E433AF92;
    uint64 constant BNB_CHAIN_SELECTOR = 13264668187771770619;
    address constant linkToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy token avec l'adresse de la lottery existante
        GoldToken goldToken = new GoldToken(
            xauUsdFeed,
            ethUsdFeed,
            payable(LOTTERY_ADDRESS)
        );
        goldToken.initialize();

        // Mint initial tokens
        try goldToken.mint{value: 0.1 ether}() {
            console2.log("Initial tokens minted successfully");
        } catch {
            console2.log("Minting failed - continuing deployment");
        }

        // Deploy bridge
        GoldBridge goldBridge = new GoldBridge(
            sepoliaRouter,            
            address(goldToken),        
            linkToken, 
            abi.encodePacked(address(0)), 
            BNB_CHAIN_SELECTOR      
        );
        goldBridge.initialize();
        
        // Configure token avec l'adresse du bridge
        goldToken.setBridgeAddress(address(goldBridge));
        goldToken.approve(address(goldBridge), type(uint256).max);

        console2.log("Deployed on Sepolia:");
        console2.log("Token:", address(goldToken));
        console2.log("Bridge:", address(goldBridge));

        vm.stopBroadcast();
    }
}
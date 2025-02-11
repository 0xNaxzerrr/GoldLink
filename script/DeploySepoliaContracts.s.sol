// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/bridge/GoldBridge.sol";
import "../src/tokens/GoldToken.sol";

contract DeploySepoliaContracts is Script {
    address sepoliaRouter;
    address xauUsdFeed;
    address ethUsdFeed;
    address LOTTERY_ADDRESS;
    address linkToken;
    uint64 BNB_CHAIN_SELECTOR;

    function setUp() public {
        sepoliaRouter = vm.envAddress("ROUTER_ETH");
        xauUsdFeed = vm.envAddress("XAU_USD_FEED");
        ethUsdFeed = vm.envAddress("ETH_USD_FEED");
        LOTTERY_ADDRESS = vm.envAddress("LOTTERY_ADDRESS");
        linkToken = vm.envAddress("LINK_SEPOLIA");
        BNB_CHAIN_SELECTOR = uint64(vm.envUint("BNB_CHAIN_SELECTOR"));
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Récupérer le nonce correct
        uint256 currentNonce = vm.getNonce(deployer);
        console2.log("Current Nonce:", currentNonce);

        uint256 gasPrice = block.basefee * 2; // Ou utilisez une valeur fixe
        vm.txGasPrice(gasPrice);

        vm.startBroadcast(deployerPrivateKey);

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

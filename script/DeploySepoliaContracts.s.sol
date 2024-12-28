// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/GoldBridge.sol";
import "../src/GoldToken.sol";
import "../src/GoldLottery.sol";
import "@chainlink/contracts/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/shared/interfaces/LinkTokenInterface.sol";

contract DeploySepoliaContracts is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
        address linkToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

        address xauUsdFeed = 0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea; 
        address ethUsdFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306; 

        address sepoliaRouter = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;

        uint64 subscriptionId = VRFCoordinatorV2Interface(vrfCoordinator)
            .createSubscription();
        console.log("Created subscription with ID:", subscriptionId);

        LinkTokenInterface(linkToken).transferAndCall(
            vrfCoordinator,
            2 * 10**18,
            abi.encode(subscriptionId)
        );
        console.log("Funded subscription with 2 LINK");

        GoldLottery goldLottery = new GoldLottery(
            subscriptionId,
            vrfCoordinator,
            msg.sender
        );
        VRFCoordinatorV2Interface(vrfCoordinator).addConsumer(
            subscriptionId,
            address(goldLottery)
        );
        console.log("Added GoldLottery as consumer to subscription");
        console.log("Sepolia - GoldLottery deployed at:", address(goldLottery));


        GoldToken goldToken = new GoldToken(
            xauUsdFeed,
            ethUsdFeed,
            payable(address(goldLottery))
        );

        //Prix par gramme d'or (USD) = 2620 / 31.1034768 ≈ 84.29 USD

        goldToken.mint{value: 0.2 ether}();
        // goldToken.adminMint(msg.sender, 1000e18);

        GoldBridge goldBridge = new GoldBridge(
            sepoliaRouter,
            address(goldToken),
            abi.encodePacked(address(0)), 
            16015286601757825753 
        );

        goldToken.setBridgeAddress(address(goldBridge));
        goldToken.approve(address(goldBridge), type(uint256).max);

        console.log("Sepolia - GoldToken deployed at:", address(goldToken));
        console.log("Sepolia - GoldBridge deployed at:", address(goldBridge));

        vm.stopBroadcast();
    }
}

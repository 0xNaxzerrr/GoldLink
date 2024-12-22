// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/GoldBridge.sol";
import "../src/GoldToken.sol";
import "../src/GoldLottery.sol";

contract DeploySepoliaContracts is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
        address goldPriceFeed = 0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea;
        address sepoliaRouter = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
        uint256 subscriptionId = 43127901903374858311685068718890716971624996036187321861613638393845931199627;

        console.log("Deploying contracts with the following parameters:");
        console.log("VRF Coordinator:", vrfCoordinator);
        console.log("Gold Price Feed:", goldPriceFeed);
        console.log("Sepolia Router:", sepoliaRouter);
        console.log("VRF Subscription ID:", subscriptionId);

        GoldLottery goldLottery = new GoldLottery(
            subscriptionId,
            vrfCoordinator,
            msg.sender
        );
        require(address(goldLottery) != address(0), "GoldLottery deployment failed");
        console.log("Sepolia - GoldLottery deployed at:", address(goldLottery));

        GoldToken goldToken = new GoldToken(
            goldPriceFeed,
            payable(address(goldLottery))
        );
        require(address(goldToken) != address(0), "GoldToken deployment failed");
        console.log("Sepolia - GoldToken deployed at:", address(goldToken));

        goldToken.mint{value: 0.2 ether}();
        goldToken.adminMint(msg.sender, 1000e18);

        GoldBridge goldBridge = new GoldBridge(
            sepoliaRouter,
            address(goldToken),
            abi.encodePacked(address(0)),
            16015286601757825753 
        );
        require(address(goldBridge) != address(0), "GoldBridge deployment failed");
        console.log("Sepolia - GoldBridge deployed at:", address(goldBridge));

        goldToken.setBridgeAddress(address(goldBridge));
        goldToken.approve(address(goldBridge), type(uint256).max);

        console.log("Deployment and initial setup completed successfully");

        vm.stopBroadcast();
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/GoldBridge.sol";
import "../src/GoldToken.sol";
import "../src/MockPriceFeed.sol";
import "../src/GoldLottery.sol";
import "@chainlink/contracts/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract DeploySepoliaContracts is Script {
    function run() external {
        uint64 nonce = vm.getNonce(msg.sender);
        vm.setNonce(msg.sender, nonce);
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address sepoliaRouter = 0xD0daae2231E9CB96b94C8512223533293C3693Bf;

        VRFCoordinatorV2Mock vrfCoordinator = new VRFCoordinatorV2Mock(0.1 ether, 0.1 ether);
        uint64 subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 1 ether);

        MockPriceFeed mockFeed = new MockPriceFeed(int256(1e15));

        GoldLottery goldLottery = new GoldLottery(subId, address(vrfCoordinator), msg.sender);
        vrfCoordinator.addConsumer(subId, address(goldLottery));

        console.log("Sepolia - GoldLottery deployed at:", address(goldLottery));

        GoldToken goldToken = new GoldToken(address(mockFeed), payable(address(goldLottery)));

        goldToken.mint{value: 0.2 ether}();
        goldToken.adminMint(msg.sender, 1000e18);

        GoldBridge goldBridge = new GoldBridge(sepoliaRouter, address(goldToken), abi.encodePacked(address(0)), 97);

        goldToken.setBridgeAddress(address(goldBridge));
        goldToken.approve(address(goldBridge), type(uint256).max);

        console.log("Sepolia - GoldToken deployed at:", address(goldToken));
        console.log("Sepolia - GoldBridge deployed at:", address(goldBridge));

        vm.stopBroadcast();
    }
}
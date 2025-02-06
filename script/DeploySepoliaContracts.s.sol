// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/bridge/GoldBridge.sol";
import "../src/tokens/GoldToken.sol"; 
import "../src/lottery/GoldLottery.sol";
import "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import "@chainlink/contracts/shared/interfaces/LinkTokenInterface.sol";

contract DeploySepoliaContracts is Script {
    address constant vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    address constant linkToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address constant sepoliaRouter = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address constant xauUsdFeed = 0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea;
    address constant ethUsdFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    bytes32 constant KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 constant CALLBACK_GAS_LIMIT = 2500000;
    uint16 constant REQUEST_CONFIRMATIONS = 3; 
    //uint256 constant SUBSCRIPTION_FUNDING = 2; 

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        uint256 subId = IVRFCoordinatorV2Plus(vrfCoordinator).createSubscription();
        console2.log("Created VRF subscription:", subId);
        console2.log("Created VRF subscription (hex):", vm.toString(subId));
        console2.log("Created VRF subscription (dec):", subId);
        LinkTokenInterface(linkToken).approve(vrfCoordinator, 2 ether);
        require(
            LinkTokenInterface(linkToken).transferAndCall(
                vrfCoordinator,
                2 ether,
                abi.encode(subId)
            ),
            "Subscription funding failed"
        );
        console2.log("Funded subscription with 2eth");

        GoldLottery goldLottery = new GoldLottery(
            vrfCoordinator,
            KEY_HASH,
            subId,
            CALLBACK_GAS_LIMIT,
            REQUEST_CONFIRMATIONS
        );

        IVRFCoordinatorV2Plus(vrfCoordinator).addConsumer(subId, address(goldLottery));
        console2.log("Added Lottery as VRF consumer");

        goldLottery.initialize();

        GoldToken goldToken = new GoldToken(
            xauUsdFeed,
            ethUsdFeed,
            payable(address(goldLottery))
        );
        goldToken.initialize();

        goldToken.mint{value: 0.2 ether}();

        GoldBridge goldBridge = new GoldBridge(
            sepoliaRouter,
            address(goldToken),
            abi.encodePacked(address(0)),
            13264668187771770619
        );
        goldBridge.initialize();
        
        goldToken.setBridgeAddress(address(goldBridge));
        goldToken.approve(address(goldBridge), type(uint256).max);

        console2.log("Deployed contracts:");
        console2.log("Lottery:", address(goldLottery));
        console2.log("Token:", address(goldToken));
        console2.log("Bridge:", address(goldBridge));

        vm.stopBroadcast();
    }
}
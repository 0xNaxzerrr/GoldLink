// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/lottery/GoldLottery.sol";
import "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import "@chainlink/contracts/shared/interfaces/LinkTokenInterface.sol";

contract DeployVRFLottery is Script {
    address constant vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    address constant linkToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    
    bytes32 constant KEY_HASH = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 constant CALLBACK_GAS_LIMIT = 2500000;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint16 constant AMOUNT_SUBSCRIBTION = 2;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        uint256 subId = IVRFCoordinatorV2Plus(vrfCoordinator).createSubscription();
        console2.log("Created VRF subscription:", subId);
        
        LinkTokenInterface(linkToken).approve(vrfCoordinator, AMOUNT_SUBSCRIBTION);
        require(
            LinkTokenInterface(linkToken).transferAndCall(
                vrfCoordinator,
                AMOUNT_SUBSCRIBTION,
                abi.encode(subId)
            ),
            "Subscription funding failed"
        );
        console2.log("Funded subscription with 2 LINK");

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
        
        console2.log("Deployed Lottery at:", address(goldLottery));
        console2.log("VRF Subscription ID:", subId);

        vm.stopBroadcast();
    }
}
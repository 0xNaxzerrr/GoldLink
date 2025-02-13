pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/bridge/GoldBridgeV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract UpgradeGoldBridge is Script {
    address constant PROXY_ADDRESS = 0xfAdFbe17e7a727CCE8ba3B39d8cf08e4f85A155b;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // Déploie la nouvelle implémentation V2
        GoldBridgeV2 newGoldBridgeV2 = new GoldBridgeV2(
            0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59,
            0xc8efbAb8c4eC6B3cC3d0474232C3cc6edF07B15b,
            0x779877A7B0D9E8603169DdbD7836e478b4624789,
            abi.encodePacked(0x801345D1E72A4fC448C83df0aa6fbED9fBb2AA3D),
            12532609583862916517
        );

        console2.log("New implementation deployed at:", address(newGoldBridgeV2));

        (bool success, ) = PROXY_ADDRESS.call(
            abi.encodeWithSignature(
                "upgradeToAndCall(address,bytes)",
                address(newGoldBridgeV2),
                ""
            )
        );
        require(success, "Upgrade failed");

        console2.log("Upgrade successful!");

        try GoldBridgeV2(PROXY_ADDRESS).version() returns (string memory ver) {
            console2.log("New version:", ver);
        } catch {
            console2.log("Version check failed");
        }

        vm.stopBroadcast();
    }
}
pragma solidity ^0.8.24;

import {GoldBridge} from "./GoldBridge.sol";

contract GoldBridgeV2 is GoldBridge {
    string internal constant VERSION = "2.0.0";

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _routerAddress,
        address _goldToken,
        address _linkToken,
        bytes memory _remoteContract,
        uint64 _destinationChainId
    ) GoldBridge(
        _routerAddress,
        _goldToken,
        _linkToken,
        _remoteContract,
        _destinationChainId
    ) {}

    function version() external pure returns (string memory) {
        return VERSION;
    }

    function getVersion() external pure returns (string memory) {
        return VERSION;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";

contract VRFCoordinatorV2_5Mock {
    event RandomWordsRequested(
        bytes32 indexed keyHash,
        uint256 requestId,
        uint256 preSeed,
        uint256 indexed subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        bytes extraArgs,
        address indexed sender
    );

    uint256 private s_nextRequestId = 1;
    mapping(uint256 => address) private s_requests;

    constructor() {}

    function requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest calldata req
    ) external returns (uint256) {
        uint256 requestId = s_nextRequestId++;
        s_requests[requestId] = msg.sender;

        emit RandomWordsRequested(
            req.keyHash,
            requestId,
            0,
            req.subId,
            req.requestConfirmations,
            req.callbackGasLimit,
            req.numWords,
            req.extraArgs,
            msg.sender
        );

        return requestId;
    }

    function fulfillRandomWords(uint256 requestId, address requester) external {
        require(s_requests[requestId] == requester, "Wrong requester");
        
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = uint256(keccak256(abi.encode(requestId, block.timestamp)));
        
        VRFConsumerBaseV2Plus(requester).rawFulfillRandomWords(
            requestId,
            randomWords
        );
    }

    function createSubscription() external pure returns (uint256) {
        return 1;
    }

    function addConsumer(uint256, address) external pure {}
    
    function fundSubscription(uint256, uint96) external pure {}
}
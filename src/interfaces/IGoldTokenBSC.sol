// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGoldTokenBSC {
    error UnauthorizedBridge();
    
    event BridgeMint(address indexed to, uint256 amount);
    event BridgeBurn(address indexed from, uint256 amount);

    function bridgeMint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
    function setBridge(address _newBridge) external;
}
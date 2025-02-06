// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGoldToken {
    error InvalidValue();
    error InvalidFeeds();
    error InsufficientBalance();
    error UnauthorizedBridge();
    error StalePrice();
    error InvalidDecimals();
    error InvalidRound();

    event TokensMinted(address indexed to, uint256 amount, uint256 fees);
    event TokensBurned(address indexed from, uint256 amount, uint256 fees);

    function mint() external payable;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
    function adminMint(address to, uint256 amount) external;
    function setBridgeAddress(address _bridge) external;
    function bridgeMint(address to, uint256 amount) external;
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IGoldTokenBSC.sol";

/// @title Gold Token BSC Implementation
/// @notice BSC version of the Gold Token for cross-chain bridging
/// @dev Implements bridge functionality for BSC chain
contract GoldTokenBSC is IGoldTokenBSC, ERC20, Ownable {
    address public bridge;

    /// @notice Constructor initializes token
    constructor() ERC20("Gold Token BSC", "GOLDBSC") Ownable(msg.sender) {}

    function setBridge(address _newBridge) external override onlyOwner {
        if (_newBridge == address(0)) revert UnauthorizedBridge();
        bridge = _newBridge;
    }

    /// @notice Mints tokens when bridged from Ethereum
    /// @param to Recipient address
    /// @param amount Amount to mint
    function bridgeMint(address to, uint256 amount) external override {
        if (msg.sender != bridge) revert UnauthorizedBridge();
        _mint(to, amount);
        emit BridgeMint(to, amount);
    }

    /// @notice Burns tokens from sender
    /// @param amount Amount to burn
    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    /// @notice Burns tokens from specified account
    /// @param account Account to burn from
    /// @param amount Amount to burn
    function burnFrom(address account, uint256 amount) external override {
        if (msg.sender != bridge) revert UnauthorizedBridge();
        
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
        
        emit BridgeBurn(account, amount);
    }
}
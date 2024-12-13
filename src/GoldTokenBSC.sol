// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GoldTokenBSC is ERC20, Ownable {
    address public bridge;

    event BridgeMint(address indexed to, uint256 amount);
    event BridgeBurn(address indexed from, uint256 amount);

    constructor(address _bridge) ERC20("Gold Token BSC", "GOLDBSC") Ownable(msg.sender) {
        bridge = _bridge;
    }

    function bridgeMint(address to, uint256 amount) external {
        require(msg.sender == bridge, "Only bridge can mint");
        _mint(to, amount);
        emit BridgeMint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        require(msg.sender == bridge, "Only bridge can burn");
        _burn(account, amount);
        emit BridgeBurn(account, amount);
    }

    function setBridge(address _newBridge) external onlyOwner {
        bridge = _newBridge;
    }
}
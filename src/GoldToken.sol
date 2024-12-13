// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/local/src/data-feeds/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GoldLottery.sol";

contract GoldToken is ERC20("GoldToken", "GOLD"), Ownable {
    AggregatorV3Interface internal priceFeed;
    address payable public goldLottery;
    address public bridgeAddress;
    uint256 public constant FEE_PERCENTAGE = 5;

    event TokensMinted(address indexed user, uint256 amount, uint256 feeTokens);
    event TokensBurned(address indexed user, uint256 amount, uint256 feeTokens);

    constructor(
        address _priceFeed,
        address payable _goldLottery
    ) Ownable(msg.sender) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        goldLottery = _goldLottery;
    }

    function mint() external payable {
        require(msg.value > 0, "Must send ETH");
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid gold price");

        uint256 goldPriceInEth = uint256(price);
        uint256 goldAmount = (msg.value * 1e18) / goldPriceInEth;
        uint256 fee = (goldAmount * FEE_PERCENTAGE) / 100;
        uint256 mintAmount = goldAmount - fee;
        uint256 feeWei = (fee * goldPriceInEth) / 1e18;

        require(feeWei < msg.value, "Fee exceeds sent ETH");

        GoldLottery(goldLottery).depositFees{value: feeWei}(feeWei);
        GoldLottery(goldLottery).enterLottery(msg.sender, mintAmount);

        _mint(msg.sender, mintAmount);
        emit TokensMinted(msg.sender, mintAmount, fee);
    }

    function burn(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");

        uint256 goldPriceInEth = uint256(price);
        uint256 ethAmount = (amount * goldPriceInEth) / 1e18;
        uint256 feeTokens = (amount * FEE_PERCENTAGE) / 100;
        uint256 feeWei = (feeTokens * goldPriceInEth) / 1e18;

        require(feeWei < ethAmount, "Fee exceeds ETH amount");

        uint256 burnAmount = ethAmount - feeWei;
        _burn(msg.sender, amount);
        GoldLottery(goldLottery).depositFees{value: feeWei}(feeWei);

        payable(msg.sender).transfer(burnAmount);
        emit TokensBurned(msg.sender, amount, feeTokens);
    }

    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }

    function adminMint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function setBridgeAddress(address _bridge) external onlyOwner {
        bridgeAddress = _bridge;
    }

    function bridgeMint(address to, uint256 amount) external {
        require(msg.sender == bridgeAddress, "Only bridge");
        _mint(to, amount);
    }
}

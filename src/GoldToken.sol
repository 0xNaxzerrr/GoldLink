// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/local/src/data-feeds/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GoldLottery.sol";

contract GoldToken is ERC20("GoldToken", "GOLD"), Ownable {
    AggregatorV3Interface public xauUsdFeed;
    AggregatorV3Interface public ethUsdFeed;
    address payable public goldLottery;
    address public bridgeAddress;
    uint256 public constant FEE_PERCENTAGE = 5;
    uint256 public constant TROY_OUNCE_IN_GRAMS = 31_103_476_800; 

    event TokensMinted(address indexed user, uint256 amount, uint256 feeTokens);
    event TokensBurned(address indexed user, uint256 amount, uint256 feeTokens);

    constructor(
        address _xauUsdFeed,
        address _ethUsdFeed,
        address payable _goldLottery
    ) Ownable(msg.sender) {
        xauUsdFeed = AggregatorV3Interface(_xauUsdFeed);
        ethUsdFeed = AggregatorV3Interface(_ethUsdFeed);
        goldLottery = _goldLottery;
    }

    function mint() external payable {
        require(msg.value > 0, "Must send ETH");

        (, int256 xauUsdPrice, , , ) = xauUsdFeed.latestRoundData();
        (, int256 ethUsdPrice, , , ) = ethUsdFeed.latestRoundData();
        require(xauUsdPrice > 0 && ethUsdPrice > 0, "Invalid feeds");

        uint256 xauUsd = uint256(xauUsdPrice);
        uint256 ethUsd = uint256(ethUsdPrice);

        // Prix d'un gramme d'or en USD (avec 8 décimales)
        uint256 gramGoldUsd = (xauUsd * 1e8) / TROY_OUNCE_IN_GRAMS;
        
        // Prix d'un gramme d'or en ETH (avec 18 décimales)
        uint256 gramGoldEth = (gramGoldUsd * 1e18) / ethUsd;
        require(gramGoldEth > 0, "Invalid ratio");

        // Nombre de grammes d'or (tokens) qu'on peut acheter avec msg.value
        uint256 goldAmount = (msg.value * 1e18) / gramGoldEth;

        uint256 feeTokens = (goldAmount * FEE_PERCENTAGE) / 100;
        uint256 mintAmount = goldAmount - feeTokens;

        uint256 feeWei = (feeTokens * msg.value) / goldAmount;
        require(feeWei < msg.value, "Fee too high");

        GoldLottery(goldLottery).depositFees{value: feeWei}(feeWei);
        GoldLottery(goldLottery).enterLottery(msg.sender, mintAmount);

        _mint(msg.sender, mintAmount);
        emit TokensMinted(msg.sender, mintAmount, feeTokens);
    }

    function burn(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Not enough tokens");

        (, int256 xauUsdPrice, , , ) = xauUsdFeed.latestRoundData();
        (, int256 ethUsdPrice, , , ) = ethUsdFeed.latestRoundData();
        require(xauUsdPrice > 0 && ethUsdPrice > 0, "Invalid feeds");

        uint256 xauUsd = uint256(xauUsdPrice);
        uint256 ethUsd = uint256(ethUsdPrice);

        // Prix d'un gramme d'or en USD (avec 8 décimales)
        uint256 gramGoldUsd = (xauUsd * 1e8) / TROY_OUNCE_IN_GRAMS;
        
        // Prix d'un gramme d'or en ETH (avec 18 décimales)
        uint256 gramGoldEth = (gramGoldUsd * 1e18) / ethUsd;
        require(gramGoldEth > 0, "Invalid ratio");

        uint256 ethAmount = (amount * gramGoldEth) / 1e18;

        uint256 feeTokens = (amount * FEE_PERCENTAGE) / 100;
        uint256 feeWei = (feeTokens * ethAmount) / amount;
        uint256 burnWei = ethAmount - feeWei;

        _burn(msg.sender, amount);

        GoldLottery(goldLottery).depositFees{value: feeWei}(feeWei);

        payable(msg.sender).transfer(burnWei);
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
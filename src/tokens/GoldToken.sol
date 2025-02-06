// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";
import "../interfaces/IGoldToken.sol";
import "../interfaces/IGoldLottery.sol";
import "forge-std/console2.sol";

/// @title Gold Token with Price Oracle and UUPS Upgrades
/// @notice ERC20 token tracking gold price with bridge capabilities
/// @dev Implements Chainlink price feeds, UUPS pattern and bridging functionality
contract GoldToken is IGoldToken, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {

    /// @notice XAU/USD price feed from Chainlink
    AggregatorV3Interface public immutable xauUsdFeed;
    
    /// @notice ETH/USD price feed from Chainlink
    AggregatorV3Interface public immutable ethUsdFeed;
    
    /// @notice Lottery contract address
    address payable public immutable goldLottery;
    
    /// @notice Bridge contract address for cross-chain transfers
    address public bridgeAddress;

    /// @notice Fee percentage applied on mint/burn operations (5%)
    uint256 public constant FEE_PERCENTAGE = 5;
    
    uint256 private constant STALENESS_PERIOD = 1 hours;

    uint256 public constant TROY_OUNCE_IN_GRAMS = 31_103_476_800;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _xauUsdFeed,
        address _ethUsdFeed,
        address payable _goldLottery
    ) {
        if (_xauUsdFeed == address(0) || _ethUsdFeed == address(0) || _goldLottery == address(0)) 
            revert InvalidValue();
        xauUsdFeed = AggregatorV3Interface(_xauUsdFeed);
        ethUsdFeed = AggregatorV3Interface(_ethUsdFeed);
        goldLottery = _goldLottery;
    }

    /// @notice Initializes the upgradeable contract
    /// @dev Should be called only once by proxy
    function initialize() external initializer {
        __ERC20_init("GoldToken", "GOLD");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /// @notice Mints tokens based on ETH sent
    /// @dev Calculates token amount based on gold price
    function mint() external payable {
        require(msg.value > 0, "Must send ETH");

        (, int256 xauUsdPrice, , , ) = xauUsdFeed.latestRoundData();
        (, int256 ethUsdPrice, , , ) = ethUsdFeed.latestRoundData();
        require(xauUsdPrice > 0 && ethUsdPrice > 0, "Invalid feeds");

        uint256 xauUsd = uint256(xauUsdPrice); 
        uint256 ethUsd = uint256(ethUsdPrice); 

        uint256 gramGoldUsd = (xauUsd * 1e8) / TROY_OUNCE_IN_GRAMS;

        uint256 gramGoldEth = (gramGoldUsd * 1e19) / ethUsd;
        require(gramGoldEth > 0, "Invalid ratio");

        uint256 goldAmount = (msg.value * 1e18) / gramGoldEth;

        uint256 feeTokens = (goldAmount * FEE_PERCENTAGE) / 100;
        uint256 mintAmount = goldAmount - feeTokens;

        uint256 feeWei = (msg.value * feeTokens) / goldAmount;
        require(feeWei < msg.value, "Fee too high");

        IGoldLottery(goldLottery).depositFees{value: feeWei}(feeWei);
        IGoldLottery(goldLottery).enterLottery(msg.sender, mintAmount);

        _mint(msg.sender, mintAmount);

        emit TokensMinted(msg.sender, mintAmount, feeTokens);
    }

    /// @notice Burns tokens and returns ETH
    /// @param amount Amount of tokens to burn
    function burn(uint256 amount) external override {
        if (balanceOf(msg.sender) < amount) revert InsufficientBalance();

        (, int256 xauUsdPrice, , , ) = xauUsdFeed.latestRoundData();
        (, int256 ethUsdPrice, , , ) = ethUsdFeed.latestRoundData();
        if (xauUsdPrice <= 0 || ethUsdPrice <= 0) revert InvalidFeeds();

        uint256 xauUsd = uint256(xauUsdPrice);
        uint256 ethUsd = uint256(ethUsdPrice);

        uint256 gramGoldUsd = (xauUsd * 1e8) / TROY_OUNCE_IN_GRAMS;
        uint256 gramGoldEth = (gramGoldUsd * 1e18) / ethUsd;
        if (gramGoldEth == 0) revert InvalidValue();

        uint256 ethAmount = (amount * gramGoldEth) / 1e18;

        uint256 feeTokens = (amount * FEE_PERCENTAGE) / 100;
        uint256 feeWei = (feeTokens * ethAmount) / amount;
        uint256 burnWei = ethAmount - feeWei;

        _burn(msg.sender, amount);
        IGoldLottery(goldLottery).depositFees{value: feeWei}(feeWei);

        payable(msg.sender).transfer(burnWei);
        emit TokensBurned(msg.sender, amount, feeTokens);
    }

    /// @notice Burns tokens from an approved address
    /// @param account Address to burn from
    /// @param amount Amount of tokens to burn
    function burnFrom(address account, uint256 amount) external override {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }

    /// @notice Allows owner to mint tokens
    /// @param to Recipient address
    /// @param amount Amount to mint
     function adminMint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Sets the bridge contract address
    /// @param _bridge New bridge address
    function setBridgeAddress(address _bridge) external override onlyOwner {
        if (_bridge == address(0)) revert InvalidValue();
        bridgeAddress = _bridge;
    }

    /// @notice Mints tokens from bridge
    /// @param to Recipient address
    /// @param amount Amount to mint
    function bridgeMint(address to, uint256 amount) external override {
        if (msg.sender != bridgeAddress) revert UnauthorizedBridge();
        _mint(to, amount);
    }

    /// @notice Authorizes an upgrade to a new implementation
    /// @dev Only owner can upgrade the contract
    /// @param newImplementation Address of new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
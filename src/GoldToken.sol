// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GoldLottery.sol";
import "forge-std/console.sol";

/**
 * @title GoldToken
 * @notice This ERC20 token represents gold, where 1 token = 1 gram of gold. Users can mint tokens by sending ETH,
 *         and the token supply dynamically adjusts based on mint and burn operations. Fees collected during mint and burn
 *         are used to fund a lottery, where a random participant wins the accumulated fees after every 1000 tokens minted.
 */
contract GoldToken is ERC20("GoldToken", "GOLD"), Ownable {
    AggregatorV3Interface internal priceFeed; // XAU/USD : 0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea
    address payable public goldLottery;
    uint256 public constant FEE_PERCENTAGE = 5;

    /**
     * @dev Emitted when tokens are minted.
     * @param user The address of the user who minted the tokens.
     * @param amount The amount of tokens minted.
     * @param fee The fee deducted during the minting process.
     */
    event TokensMinted(address indexed user, uint256 amount, uint256 fee);

    /**
     * @dev Emitted when tokens are burned.
     * @param user The address of the user who burned the tokens.
     * @param amount The amount of tokens burned.
     * @param fee The fee deducted during the burning process.
     */
    event TokensBurned(address indexed user, uint256 amount, uint256 fee);

    /**
     * @notice Initializes the GoldToken contract.
     * @param _priceFeed The address of the Chainlink price feed for gold in ETH.
     * @param _goldLottery The address of the GoldLottery contract.
     */
    constructor(
        address _priceFeed,
        address payable _goldLottery
    ) Ownable(msg.sender) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        goldLottery = _goldLottery;
    }

    /**
     * @notice Mint tokens based on the current price of gold in ETH.
     * @dev The amount of ETH sent determines the number of tokens minted, based on the gold price fetched from Chainlink.
     *      A 5% fee is deducted and sent to the lottery contract. The user's minting also registers them as a participant
     *      in the lottery.
     */
    function mint() external payable {
        require(msg.value > 0, "Must send ETH to mint tokens");

        // Log ETH envoyé
        console.log("ETH sent:", msg.value);

        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid gold price");

        // Log du prix de l'or
        console.log("Gold price (in ETH):", uint256(price));

        uint256 goldPriceInEth = uint256(price);
        uint256 goldAmount = (msg.value * 1e18) / goldPriceInEth; // Convert ETH to grams of gold

        // Log du montant de GOLD calculé
        console.log("Gold amount:", goldAmount);
        // Calculate fee
        uint256 fee = (goldAmount * FEE_PERCENTAGE) / 100;
        uint256 mintAmount = goldAmount - fee;

        // Transfer the fee to the lottery contract
        payable(goldLottery).transfer(fee);

        // Register the user in the lottery
        GoldLottery(goldLottery).enterLottery(msg.sender, mintAmount);

        // Deposit the fee into the lottery balance
        GoldLottery(goldLottery).depositFees{value: fee}(fee);

        // Mint the tokens to the sender
        _mint(msg.sender, mintAmount);

        emit TokensMinted(msg.sender, mintAmount, fee);
    }

    /**
     * @notice Burn tokens to retrieve ETH based on the current price of gold.
     * @dev The user must hold enough tokens to burn. The ETH returned is calculated based on the gold price
     *      fetched from Chainlink. A 5% fee is deducted and sent to the lottery contract.
     * @param amount The amount of tokens to burn.
     */
    function burn(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient token balance");

        // Fetch the latest price of gold in ETH
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid gold price");

        uint256 goldPriceInEth = uint256(price);
        uint256 ethAmount = (amount * goldPriceInEth) / 1e18;

        // Calculate fee
        uint256 fee = (ethAmount * FEE_PERCENTAGE) / 100;
        uint256 burnAmount = ethAmount - fee;

        // Burn the tokens
        _burn(msg.sender, amount);

        // Transfer the fee to the lottery contract
        payable(goldLottery).transfer(fee);

        // Send the remaining ETH to the user
        payable(msg.sender).transfer(burnAmount);

        emit TokensBurned(msg.sender, amount, fee);
    }

    /**
     * @notice Updates the address of the GoldLottery contract.
     * @dev Only callable by the owner (optional, can add AccessControl if needed).
     * @param _goldLottery The new address of the GoldLottery contract.
     */
    function setGoldLottery(address payable _goldLottery) external onlyOwner {
        require(_goldLottery != address(0), "Invalid lottery address");
        goldLottery = _goldLottery;
    }

    /**
     * @notice Fallback function to allow the contract to receive ETH directly.
     * @dev This is required for handling ETH sent to the contract.
     */
    receive() external payable {}
}

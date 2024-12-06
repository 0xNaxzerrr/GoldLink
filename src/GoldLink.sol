// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/local/src/data-feeds/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title GoldLink Contract
/// @author 0xNaxzerrr
/// @notice This contract allows users to swap USDT for XAU (Gold) based on live Chainlink price feeds.
/// @dev The contract uses Chainlink Price Feeds for XAU/USD and supports ERC-20 USDT for payments.
contract GoldLink is Ownable {
    /// @notice The Chainlink price feed for XAU/USD
    AggregatorV3Interface internal dataFeed;

    /// @notice The USDT ERC-20 token contract
    IERC20 public usdtToken;

    /// @notice Commission percentage taken on each swap (e.g., 5%)
    uint256 private constant COMMISSION_PERCENT = 5;

    /// @param _dataFeed The address of the Chainlink XAU/USD price feed
    /// @param _usdtToken The address of the USDT ERC-20 token contract
    constructor(address _dataFeed, address _usdtToken) Ownable(msg.sender) {
        dataFeed = AggregatorV3Interface(_dataFeed);
        usdtToken = IERC20(_usdtToken);
    }

    /// @notice Allows users to swap USDT for XAU (Gold) minus a 5% commission
    /// @dev Transfers USDT from the user to the contract, calculates XAU equivalent, and sends XAU to the user
    /// @param usdtAmount The amount of USDT the user wants to spend
    function Swap(uint256 usdtAmount) public {
        require(usdtAmount > 0, "USDT amount must be greater than zero");

        // Transfer USDT from user to contract
        require(
            usdtToken.transferFrom(msg.sender, address(this), usdtAmount),
            "USDT transfer failed"
        );

        // Calculate XAU amount based on price feed
        uint256 xauAmount = getXAUAmount(usdtAmount);

        // Apply 5% commission
        uint256 commission = (xauAmount * COMMISSION_PERCENT) / 100;
        uint256 finalXAUAmount = xauAmount - commission;

        // Simulate mint or transfer of XAU to user
        _transferXAU(msg.sender, finalXAUAmount);
    }

    /// @notice Calculates the equivalent amount of XAU (Gold) for a given USDT amount
    /// @dev Uses the Chainlink XAU/USD price feed for conversion
    /// @param usdtAmount The amount of USDT to be converted to XAU
    /// @return xauAmount The equivalent amount of XAU in the smallest unit
    function getXAUAmount(uint256 usdtAmount) public view returns (uint256) {
        (, int answer, , , ) = dataFeed.latestRoundData();
        require(answer > 0, "Invalid price feed data");

        // Chainlink price feed for XAU/USD has 8 decimals
        // USDT has 6 decimals
        // XAU amount = (USDT amount / XAU price in USD) adjusted for decimals
        uint256 xauAmount = (usdtAmount * 10 ** 8) / uint256(answer);

        return xauAmount;
    }

    /// @notice Retrieves the current balance of USDT held by the contract
    /// @return The balance of USDT in the contract
    function getContractUSDTBalance() public view returns (uint256) {
        return usdtToken.balanceOf(address(this));
    }

    /// @notice Allows the contract owner to withdraw accumulated USDT
    /// @dev Transfers all USDT held by the contract to the owner's address
    function withdrawUSDT() public onlyOwner {
        uint256 balance = getContractUSDTBalance();
        require(balance > 0, "No USDT to withdraw");
        require(
            usdtToken.transfer(msg.sender, balance),
            "USDT withdrawal failed"
        );
    }

    /// @notice Internal function to simulate transferring XAU to the user
    /// @dev This function should be replaced with actual logic for minting or transferring XAU tokens
    /// @param to The address of the recipient
    /// @param amount The amount of XAU to transfer
    function _transferXAU(address to, uint256 amount) internal {
        // Emit event for transfer
        emit XAUTransferred(to, amount);
    }

    /// @notice Event emitted when XAU is transferred to a user
    /// @param to The recipient address
    /// @param amount The amount of XAU transferred
    event XAUTransferred(address indexed to, uint256 amount);
}

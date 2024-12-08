// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/GoldToken.sol";
import "../src/GoldLottery.sol";
import "../src/MockPriceFeed.sol";

contract GoldTokenTest is Test {
    GoldToken public goldToken;
    GoldLottery public goldLottery;

    address public owner = address(0xABCD);
    address public user = address(0x1234);
    address public anotherUser = address(0x5678);
    uint256 public initialPrice = 2000e18; // Simulated price of gold in ETH

    function setUp() public {
        // Deploy the GoldLottery contract
        goldLottery = new GoldLottery(1); // Mock subscription ID

        // Deploy the GoldToken contract with a mock price feed and the lottery address
        goldToken = new GoldToken(
            address(new MockPriceFeed(int256(initialPrice))), // Mock price feed
            payable(address(goldLottery))
        );

        // Make `owner` the owner of the GoldToken contract
        vm.prank(owner);
        goldToken.transferOwnership(owner);
    }

    function testMintTokens() public {
        vm.deal(user, 1 ether); // Give `user` 1 ETH

        vm.prank(user);
        goldToken.mint{value: 0.5 ether}();

        assertEq(goldToken.balanceOf(user), 475e18); // 95% of the value (with 5% fee)
    }

    function testBurnTokens() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        goldToken.mint{value: 0.5 ether}();

        uint256 initialBalance = user.balance;

        vm.prank(user);
        goldToken.burn(475e18); // Burn the minted tokens

        assert(user.balance > initialBalance); // Ensure user received ETH back
    }

    function testEnterLottery() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        goldToken.mint{value: 0.5 ether}();

        assertEq(goldLottery.tokensMinted(), 475e18); // Tokens should count for lottery
        assertEq(goldLottery.chances(user), 475e18); // User should have 475 chances
    }
}

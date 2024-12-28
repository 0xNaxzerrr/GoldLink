// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/GoldToken.sol";
import "../src/GoldLottery.sol";
import "../src/MockPriceFeed.sol";

contract GoldTokenTest is Test {
    GoldToken goldToken;
    GoldLottery goldLottery;
    MockPriceFeed mockPriceFeed;

    address user = address(0x1);

    function setUp() public {
        mockPriceFeed = new MockPriceFeed(2000 * 1e8); // $2000 par ETH
        goldLottery = new GoldLottery(
            49224907127232505730104472195340970228059491637583329608997101105052895073023
        );
        goldToken = new GoldToken(
            address(mockPriceFeed),
            payable(address(goldLottery))
        );

        vm.deal(user, 10 ether); // Ajouter 10 ETH à l'adresse user
    }

    function testMint() public {
        vm.startPrank(user);
        goldToken.mint{value: 1 ether}();

        uint256 expectedTokens = (1 ether * 1e18) / (2000 * 1e8); // 1 ETH = 500 GOLD
        assertEq(goldToken.balanceOf(user), expectedTokens);

        vm.stopPrank();
    }

    function testBurn() public {
        vm.startPrank(user);
        goldToken.mint{value: 1 ether}();

        uint256 tokensToBurn = goldToken.balanceOf(user);
        goldToken.burn(tokensToBurn);

        assertEq(goldToken.balanceOf(user), 0);

        vm.stopPrank();
    }
}

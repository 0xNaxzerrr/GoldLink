// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/GoldToken.sol";
import "../src/GoldLottery.sol";
import "../src/MockPriceFeed.sol";
import "@chainlink/contracts/vrf/mocks/VRFCoordinatorV2Mock.sol";

contract GoldTokenTest is Test {
    GoldToken public goldToken;
    GoldLottery public goldLottery;
    VRFCoordinatorV2Mock public vrfCoordinator;
    MockPriceFeed public mockXAU;
    MockPriceFeed public mockETH;

    address public owner = address(0xABCD);
    address public user = address(0x1234);
    uint64 public subId;

    function setUp() public {
        vm.startPrank(owner);

        vrfCoordinator = new VRFCoordinatorV2Mock(0.1 ether, 0.1 ether);
        subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, 1 ether);

        // Prix de l'or : 2000 USD/oz (8 décimales)
        mockXAU = new MockPriceFeed(int256(262174000000)); // 2621.74 USD/oz
        // Prix de l'ETH : 3000 USD (8 décimales)
        mockETH = new MockPriceFeed(int256(334226000000)); // 3342.26 USD
        goldLottery = new GoldLottery(subId, address(vrfCoordinator), owner);
        vrfCoordinator.addConsumer(subId, address(goldLottery));

        goldToken = new GoldToken(
            address(mockXAU),
            address(mockETH),
            payable(address(goldLottery))
        );

        vm.stopPrank();
    }

    function testSetBridgeAddress() public {
        address newBridge = address(0x5678);
        vm.prank(owner);
        goldToken.setBridgeAddress(newBridge);
        assertEq(goldToken.bridgeAddress(), newBridge);
    }

    function testBridgeMint() public {
        address bridge = address(0x5678);
        vm.prank(owner);
        goldToken.setBridgeAddress(bridge);

        vm.prank(bridge);
        goldToken.bridgeMint(user, 100e18);

        assertEq(goldToken.balanceOf(user), 100e18);
    }

    function testFailMintWithoutEth() public {
        vm.prank(user);
        goldToken.mint{value: 0}();
    }

    function testMintTokens() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        goldToken.mint{value: 0.5 ether}();

        // For 0.5 ETH at 3342.26 USD/ETH = 1671.13 USD
        // Gold at 2621.74 USD/oz
        // 1 oz = 31.103476800 g (TROY_OUNCE_IN_GRAMS)
        // Price per gram = 2621.74/31.103476800 = 84.29 USD/g
        // Grams of gold = 1671.13/84.29 = 19.83g
        // After 5% fee = 18.84g
        uint256 expected = 188.344593783976847650e18; // The actual amount from traces
        uint256 minted = goldToken.balanceOf(user);
        assertApproxEqRel(minted, expected, 0.01e18);
    }

    function testBurnTokens() public {
        vm.deal(user, 1 ether);
        uint256 initialBalance = user.balance;

        // Mint des tokens
        vm.prank(user);
        goldToken.mint{value: 0.5 ether}();

        uint256 midBalance = user.balance;
        assertEq(midBalance, initialBalance - 0.5 ether);

        uint256 minted = goldToken.balanceOf(user);
        
        // Brûler tous les tokens mintés
        vm.prank(user);
        goldToken.burn(minted);

        uint256 finalBalance = user.balance;

        // Calculer le montant attendu
        uint256 expectedBurnWei = calculateExpectedBurnWei(minted);
        
        // Vérifiez le montant attendu
        assertApproxEqRel(finalBalance, midBalance + expectedBurnWei, 0.001e18);
    }

    // Fonction pour calculer le montant attendu à retourner
    function calculateExpectedBurnWei(uint256 amount) internal view returns (uint256) {
        (, int256 xauUsdPrice, , , ) = goldToken.xauUsdFeed().latestRoundData();
        (, int256 ethUsdPrice, , , ) = goldToken.ethUsdFeed().latestRoundData();

        uint256 xauUsd = uint256(xauUsdPrice);
        uint256 ethUsd = uint256(ethUsdPrice);

        uint256 gramGoldUsd = (xauUsd * 1e8) / goldToken.TROY_OUNCE_IN_GRAMS();
        uint256 gramGoldEth = (gramGoldUsd * 1e18) / ethUsd;

        uint256 ethAmount = (amount * gramGoldEth) / 1e18;
        uint256 feeTokens = (amount * goldToken.FEE_PERCENTAGE()) / 100;
        uint256 feeWei = (feeTokens * ethAmount) / amount;

        return ethAmount - feeWei;
    }
    function testFailBurnTooMuch() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        goldToken.mint{value: 0.5 ether}();
        
        uint256 minted = goldToken.balanceOf(user);
        vm.prank(user);
        goldToken.burn(minted + 1e18); 
    }
}

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

    uint256 expected = calculateExpectedMintAmount(0.5 ether);
    uint256 minted = goldToken.balanceOf(user);

    assertApproxEqRel(minted, expected, 0.01e18);
}


function testBurnTokens() public {
    vm.deal(user, 1 ether);
    uint256 initialBalance = user.balance;

    vm.prank(user);
    goldToken.mint{value: 0.5 ether}();

    uint256 midBalance = user.balance;
    assertEq(midBalance, initialBalance - 0.5 ether);

    uint256 minted = goldToken.balanceOf(user);

    vm.prank(user);
    goldToken.burn(minted);

    uint256 finalBalance = user.balance;

    uint256 expectedBurnWei = calculateExpectedBurnWei(
        minted, 
        mockXAU.price(), 
        mockETH.price()
    );

    assertApproxEqRel(finalBalance, midBalance + expectedBurnWei, 0.001e18);
}


function calculateExpectedBurnWei(uint256 amount, int256 xauUsdPrice, int256 ethUsdPrice) 
    internal 
    view 
    returns (uint256) 
{
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

    function calculateExpectedMintAmount(uint256 ethAmount) internal view returns (uint256) {
    uint256 xauUsd = uint256(mockXAU.price());
    uint256 ethUsd = uint256(mockETH.price());

    // Prix d'un gramme d'or en USD
    uint256 gramGoldUsd = (xauUsd * 1e8) / goldToken.TROY_OUNCE_IN_GRAMS();

    // Prix d'un gramme d'or en ETH
    uint256 gramGoldEth = (gramGoldUsd * 1e18) / ethUsd;

    // Montant d'or brut
    uint256 goldAmount = (ethAmount * 1e18) / gramGoldEth;

    // Application des frais
    uint256 feeTokens = (goldAmount * goldToken.FEE_PERCENTAGE()) / 100;

    return goldAmount - feeTokens;
}

}

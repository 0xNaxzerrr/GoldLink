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

        // Les deux feeds renvoient 1e8 => ratio = 1
        // => mint(0.5 ETH) => ~5e9 tokens - 5% = 4.75e9
        mockXAU = new MockPriceFeed(int256(1e8));
        mockETH = new MockPriceFeed(int256(1e8));

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

    function testFailBurnTooMuch() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        goldToken.mint{value: 0.5 ether}();
        vm.prank(user);
        goldToken.burn(500e18); // On tente de burn plus que minté => revert
    }

    // Cas où on vérifie simplement la quantité de tokens mintés
    function testMintTokens() public {
        vm.deal(user, 1 ether);

        vm.prank(user);
        goldToken.mint{value: 0.5 ether}();

        // On s’attend à ~4.75e9
        uint256 minted = goldToken.balanceOf(user);
        assertEq(minted, 4750000000);
    }

    // Cas où on vérifie le solde final en ETH après burn
    function testBurnTokens() public {
        vm.deal(user, 1 ether);

        // solde initial
        uint256 initialBalance = user.balance;

        // L’utilisateur dépense 0.5 ETH pour minter
        vm.prank(user);
        goldToken.mint{value: 0.5 ether}();

        // On vérifie le solde "milieu"
        uint256 midBalance = user.balance;
        // midBalance devrait être environ initialBalance - 0.5
        // On autorise une petite marge
        assertApproxEqAbs(
            midBalance,
            initialBalance - 0.5 ether,
            1e14
        );

        // Combien de tokens a-t-il ?
        uint256 minted = goldToken.balanceOf(user);
        // Normalement ~4.75e9

        // On burn tout
        vm.prank(user);
        goldToken.burn(minted);

        // solde final
        uint256 finalBalance = user.balance;

        // S’il recouvre ~0.45125 ETH, alors finalBalance = midBalance + 0.45125
        uint256 expected = midBalance + 0.45125 ether;

        // On autorise 0.0005 ETH d’écart
        assertApproxEqAbs(
            finalBalance,
            expected,
            5e14
        );
    }
}

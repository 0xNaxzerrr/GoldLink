// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/tokens/GoldToken.sol";
import "../mocks/PriceFeedMock.sol";
import "../mocks/LotteryMock.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GoldTokenTest is Test {
    GoldToken public implementation;
    GoldToken public token;
    PriceFeedMock public xauUsdFeed;
    PriceFeedMock public ethUsdFeed;
    LotteryMock public lottery;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address bridge = makeAddr("bridge");

    event TokensMinted(address indexed to, uint256 amount, uint256 fees);
    event TokensBurned(address indexed from, uint256 amount, uint256 fees);

    function setUp() public {
        xauUsdFeed = new PriceFeedMock();
        ethUsdFeed = new PriceFeedMock();
        lottery = new LotteryMock();

        // Simule 2000 USD/XAU et 3000 USD/ETH
        xauUsdFeed.setPrice(2000e8);
        ethUsdFeed.setPrice(3000e8);

        // Déploie l'impl + proxy UUPS
        implementation = new GoldToken(
            address(xauUsdFeed),
            address(ethUsdFeed),
            payable(address(lottery))
        );
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(GoldToken.initialize.selector)
        );
        token = GoldToken(address(proxy));

        // Configure le bridge
        vm.prank(token.owner());
        token.setBridgeAddress(bridge);

        // Donne 100 ETH à Alice pour tester
        vm.deal(alice, 100 ether);
    }

    function testMint() public {
        uint256 mintAmount = 1 ether;

        vm.startPrank(alice);
        token.mint{value: mintAmount}();
        vm.stopPrank();

        // Alice doit avoir reçu des tokens
        assertGt(token.balanceOf(alice), 0);

        // Vérifie que la loterie a reçu ~5% de mintAmount
        // Tolère un écart max de 1 wei à cause des arrondis
        assertApproxEqAbs(
            address(lottery).balance,
            (mintAmount * 5) / 100,
            1
        );
    }

    function testBurn() public {
        vm.startPrank(alice);
        token.mint{value: 1 ether}();
        uint256 initialBalance = token.balanceOf(alice);

        token.burn(initialBalance);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 0);
    }

    function testBridgeMint() public {
        uint256 amount = 100 ether;

        vm.prank(bridge);
        token.bridgeMint(bob, amount);

        assertEq(token.balanceOf(bob), amount);
    }

    function testAdminMint() public {
        uint256 amount = 100 ether;

        vm.prank(token.owner());
        token.adminMint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
    }

    function testBurnFrom() public {
        uint256 amount = 100 ether;
        vm.prank(token.owner());
        token.adminMint(alice, amount);

        vm.startPrank(alice);
        token.approve(bob, amount);
        vm.stopPrank();

        vm.prank(bob);
        token.burnFrom(alice, amount);

        assertEq(token.balanceOf(alice), 0);
    }

    // -------------------------
    // TESTS D'ÉCHEC
    // -------------------------

    function test_RevertWhen_UnauthorizedBridgeMint() public {
        vm.prank(alice);
        vm.expectRevert(IGoldToken.UnauthorizedBridge.selector);
        token.bridgeMint(bob, 100 ether);
    }

    function test_RevertWhen_InvalidMintValue() public {
        vm.expectRevert(bytes("Must send ETH"));
        token.mint{value: 0}();
    }

    function test_RevertWhen_InsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(IGoldToken.InsufficientBalance.selector);
        token.burn(1 ether);
    }

    receive() external payable {}
}

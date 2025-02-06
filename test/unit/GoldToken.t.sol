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
        // Deploy mocks
        xauUsdFeed = new PriceFeedMock();
        ethUsdFeed = new PriceFeedMock();
        lottery = new LotteryMock();

        // Setup price feeds
        xauUsdFeed.setPrice(2000e8); // 2000 USD/XAU
        ethUsdFeed.setPrice(3000e8); // 3000 USD/ETH

        // Deploy token with proxy
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
        token.initialize();

        // Setup initial state
        token.setBridgeAddress(bridge);
        vm.deal(alice, 100 ether);
    }

    function testMint() public {
        uint256 mintAmount = 1 ether;
        
        vm.startPrank(alice);
        vm.expectEmit(true, false, false, true);
        token.mint{value: mintAmount}();
        vm.stopPrank();

        assertGt(token.balanceOf(alice), 0);
        assertEq(address(lottery).balance, mintAmount * 5 / 100); // 5% fees
    }

    function testBurn() public {
        // First mint some tokens
        vm.startPrank(alice);
        token.mint{value: 1 ether}();
        uint256 initialBalance = token.balanceOf(alice);
        
        // Then burn them
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

    function testFailUnauthorizedBridgeMint() public {
        vm.prank(alice);
        token.bridgeMint(bob, 100 ether);
    }

    function testFailInvalidMintValue() public {
        token.mint{value: 0}();
    }

    function testFailInsufficientBalance() public {
        vm.prank(alice);
        token.burn(1 ether);
    }

    receive() external payable {}
}
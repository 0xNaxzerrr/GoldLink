// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/tokens/GoldTokenBSC.sol";

contract GoldTokenBSCTest is Test {
    GoldTokenBSC public token;
    address public constant INITIAL_BRIDGE = address(0x123);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    event BridgeMint(address indexed to, uint256 amount);
    event BridgeBurn(address indexed from, uint256 amount);

    function setUp() public {
        vm.startPrank(alice);
        token = new GoldTokenBSC();
        token.setBridge(INITIAL_BRIDGE);
        vm.stopPrank();
    }

    function testBridgeMint() public {
        uint256 amount = 100 ether;
        
        vm.prank(INITIAL_BRIDGE);
        vm.expectEmit(true, false, false, true);
        emit BridgeMint(bob, amount);
        token.bridgeMint(bob, amount);
        
        assertEq(token.balanceOf(bob), amount);
    }

    function testBurn() public {
        uint256 amount = 100 ether;
        
        vm.prank(INITIAL_BRIDGE);
        token.bridgeMint(alice, amount);
        
        vm.prank(alice);
        token.burn(amount);
        
        assertEq(token.balanceOf(alice), 0);
    }

    function testBurnFrom() public {
        uint256 amount = 100 ether;
        
        vm.prank(INITIAL_BRIDGE);
        token.bridgeMint(alice, amount);
        
        vm.prank(INITIAL_BRIDGE);
        token.burnFrom(alice, amount);
        
        assertEq(token.balanceOf(alice), 0);
    }

    function testFailUnauthorizedBridgeMint() public {
        vm.prank(alice);
        token.bridgeMint(bob, 100 ether);
    }

    function testFailUnauthorizedBurnFrom() public {
        vm.prank(alice);
        token.burnFrom(bob, 100 ether);
    }
}
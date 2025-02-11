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
        // alice déploie le token, puis setBridge()
        vm.startPrank(alice);
        token = new GoldTokenBSC();
        token.setBridge(INITIAL_BRIDGE);
        vm.stopPrank();
    }

    // ------------------------------------------------
    // Tests "normaux"
    // ------------------------------------------------

    function testBridgeMint() public {
        uint256 amount = 100 ether;

        // Seul le bridge peut appeler bridgeMint
        vm.prank(INITIAL_BRIDGE);
        // On veut vérifier qu'on émet bien l'événement BridgeMint
        vm.expectEmit(true, false, false, true);
        emit BridgeMint(bob, amount);
        token.bridgeMint(bob, amount);

        assertEq(token.balanceOf(bob), amount);
    }

    function testBurn() public {
        // Mint des tokens pour alice
        vm.prank(INITIAL_BRIDGE);
        token.bridgeMint(alice, 100 ether);

        // alice burn ses propres tokens
        vm.startPrank(alice);
        token.burn(100 ether);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 0);
    }

    function testBurnFrom() public {
        // Mint des tokens pour alice
        vm.prank(INITIAL_BRIDGE);
        token.bridgeMint(alice, 100 ether);

        // Alice approuve le bridge pour dépenser ses tokens
        vm.prank(alice);
        token.approve(INITIAL_BRIDGE, 100 ether);

        // Le bridge utilise burnFrom
        vm.startPrank(INITIAL_BRIDGE);
        vm.expectEmit(true, false, false, true);
        emit BridgeBurn(alice, 100 ether);
        token.burnFrom(alice, 100 ether);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 0);
    }

    // ------------------------------------------------
    // Tests d'échec (reverts)
    // ------------------------------------------------

    function test_RevertWhen_UnauthorizedBridgeMint() public {
        // alice tente de faire un bridgeMint => revert
        vm.prank(alice);
        vm.expectRevert(IGoldTokenBSC.UnauthorizedBridge.selector);
        token.bridgeMint(bob, 100 ether);
    }

    function test_RevertWhen_UnauthorizedBurnFrom() public {
        // Mint des tokens pour bob
        vm.prank(INITIAL_BRIDGE);
        token.bridgeMint(bob, 100 ether);

        // Bob approuve alice (qui n'est pas le bridge)
        vm.prank(bob);
        token.approve(alice, 100 ether);

        // alice (non bridge) tente de burnFrom => revert
        vm.startPrank(alice);
        vm.expectRevert(IGoldTokenBSC.UnauthorizedBridge.selector);
        token.burnFrom(bob, 100 ether);
        vm.stopPrank();
    }
}

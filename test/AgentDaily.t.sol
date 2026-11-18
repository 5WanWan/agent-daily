// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/AgentDaily.sol";

/// @notice Minimal mock of the Agent ID registry: mint an Agent ID to an address.
contract MockAgentId {
    mapping(address => uint256) public balanceOf;
    mapping(address => bool) public hasId;

    function mint(address to) external {
        require(!hasId[to], "already has id");
        hasId[to] = true;
        balanceOf[to] = 1;
    }
}

contract AgentDailyTest is Test {
    MockAgentId internal registry;
    AgentDaily internal daily;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA901);

    uint256 internal constant DAY = 1 days;

    function setUp() public {
        registry = new MockAgentId();
        daily = new AgentDaily(address(registry));
        // Realistic mainnet-like timestamp so first check-in rules behave normally.
        vm.warp(1_760_000_000);
        registry.mint(alice);
        registry.mint(bob);
    }

    // (a) non-holder mint reverts
    function testNonHolderCannotMint() public {
        vm.prank(carol);
        vm.expectRevert(AgentDaily.NotAgentIdHolder.selector);
        daily.mintBadge();
    }

    // (b) holder mint succeeds, badge 1, tokenId correct
    function testHolderMintSucceeds() public {
        vm.prank(alice);
        daily.mintBadge();
        assertTrue(daily.hasBadge(alice));
        assertEq(daily.badgeTokenId(alice), 1);
        assertEq(daily.totalBadges(), 1);
        assertEq(daily.balanceOf(alice), 1);
        assertEq(daily.ownerOf(1), alice);
    }

    // (b2) second holder gets tokenId 2
    function testSecondHolderGetsTokenIdTwo() public {
        vm.prank(alice);
        daily.mintBadge();
        vm.prank(bob);
        daily.mintBadge();
        assertEq(daily.badgeTokenId(bob), 2);
        assertEq(daily.totalBadges(), 2);
    }

    // (c) second mint reverts
    function testSecondMintReverts() public {
        vm.prank(alice);
        daily.mintBadge();
        vm.prank(alice);
        vm.expectRevert(AgentDaily.AlreadyHasBadge.selector);
        daily.mintBadge();
    }

    // (d) transferFrom reverts (soulbound)
    function testTransferFromReverts() public {
        vm.prank(alice);
        daily.mintBadge();
        vm.prank(alice);
        vm.expectRevert(AgentDaily.Soulbound.selector);
        daily.transferFrom(alice, bob, 1);
    }

    // (d2) safeTransferFrom reverts (soulbound)
    function testSafeTransferFromReverts() public {
        vm.prank(alice);
        daily.mintBadge();
        vm.prank(alice);
        vm.expectRevert(AgentDaily.Soulbound.selector);
        daily.safeTransferFrom(alice, bob, 1);
    }

    // (d3) safeTransferFrom with data reverts too
    function testSafeTransferFromWithDataReverts() public {
        vm.prank(alice);
        daily.mintBadge();
        vm.prank(alice);
        vm.expectRevert(AgentDaily.Soulbound.selector);
        daily.safeTransferFrom(alice, bob, 1, "");
    }

    // (d4) approve / setApprovalForAll revert too
    function testApprovalsRevert() public {
        vm.prank(alice);
        daily.mintBadge();
        vm.prank(alice);
        vm.expectRevert(AgentDaily.Soulbound.selector);
        daily.approve(bob, 1);
        vm.prank(alice);
        vm.expectRevert(AgentDaily.Soulbound.selector);
        daily.setApprovalForAll(bob, true);
        assertEq(daily.getApproved(1), address(0));
        assertFalse(daily.isApprovedForAll(alice, bob));
    }

    // (e) check-in without badge reverts
    function testCheckInWithoutBadgeReverts() public {
        vm.prank(alice);
        vm.expectRevert(AgentDaily.NoBadge.selector);
        daily.checkIn();
    }

    // (f) check-in twice within 24h reverts
    function testDoubleCheckInWithin24hReverts() public {
        vm.prank(alice);
        daily.mintBadge();
        vm.prank(alice);
        daily.checkIn();
        vm.warp(block.timestamp + 23 hours);
        vm.prank(alice);
        vm.expectRevert(AgentDaily.CheckInTooSoon.selector);
        daily.checkIn();
    }

    // (g) check-in next day -> streak 2
    function testCheckInNextDayStreakTwo() public {
        vm.prank(alice);
        daily.mintBadge();
        vm.prank(alice);
        daily.checkIn();
        vm.warp(block.timestamp + DAY + 1);
        vm.prank(alice);
        daily.checkIn();
        assertEq(daily.streakOf(alice), 2);
        assertEq(daily.totalCheckIns(alice), 2);
        assertEq(daily.totalCheckInsAll(), 2);
    }

    // (g2) three consecutive days -> streak 3
    function testThreeDayStreak() public {
        vm.prank(alice);
        daily.mintBadge();
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(alice);
            daily.checkIn();
            vm.warp(block.timestamp + DAY + 1);
        }
        assertEq(daily.streakOf(alice), 3);
        assertEq(daily.totalCheckIns(alice), 3);
    }

    // (h) check-in after >48h gap -> streak resets to 1
    function testStreakResetsAfterGap() public {
        vm.prank(alice);
        daily.mintBadge();
        vm.prank(alice);
        daily.checkIn();
        vm.warp(block.timestamp + DAY + 1);
        vm.prank(alice);
        daily.checkIn();
        assertEq(daily.streakOf(alice), 2);
        vm.warp(block.timestamp + 3 days);
        vm.prank(alice);
        daily.checkIn();
        assertEq(daily.streakOf(alice), 1);
        assertEq(daily.totalCheckIns(alice), 3);
    }

    // (h2) check-in exactly at +2 days boundary resets (spec: < last+2d keeps streak)
    function testStreakResetsAtExactlyTwoDays() public {
        vm.prank(alice);
        daily.mintBadge();
        vm.prank(alice);
        daily.checkIn();
        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        daily.checkIn();
        assertEq(daily.streakOf(alice), 1);
    }

    // (i) view functions correct
    function testViewFunctions() public {
        assertFalse(daily.hasBadge(alice));
        assertEq(daily.streakOf(alice), 0);
        assertEq(daily.lastCheckIn(alice), 0);
        assertEq(daily.totalCheckIns(alice), 0);
        assertEq(daily.badgeTokenId(alice), 0);
        assertEq(daily.totalBadges(), 0);
        assertEq(daily.totalCheckInsAll(), 0);
        assertEq(daily.name(), "Agent Daily Badge");
        assertEq(daily.symbol(), "ADB");
        assertEq(daily.agentIdRegistry(), address(registry));

        vm.prank(alice);
        daily.mintBadge();
        uint256 t0 = block.timestamp;
        vm.prank(alice);
        daily.checkIn();
        assertTrue(daily.hasBadge(alice));
        assertEq(daily.streakOf(alice), 1);
        assertEq(daily.lastCheckIn(alice), t0);
        assertEq(daily.totalCheckIns(alice), 1);
        assertEq(daily.badgeTokenId(alice), 1);
        assertEq(daily.totalBadges(), 1);
        assertEq(daily.totalCheckInsAll(), 1);
    }

    // events emitted with the right data
    function testEvents() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, false);
        emit AgentDaily.BadgeMinted(alice, 1);
        daily.mintBadge();

        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit AgentDaily.CheckedIn(alice, 1, 1, block.timestamp);
        daily.checkIn();
    }

    // zero-address registry rejected at deploy
    function testZeroRegistryReverts() public {
        vm.expectRevert(AgentDaily.ZeroAddressRegistry.selector);
        new AgentDaily(address(0));
    }

    // ownerOf unknown token reverts
    function testOwnerOfUnknownReverts() public {
        vm.expectRevert(AgentDaily.NonexistentToken.selector);
        daily.ownerOf(999);
    }
}

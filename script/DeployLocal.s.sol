// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/AgentDaily.sol";
import "../test/AgentDaily.t.sol";

/// @notice Local smoke test only (anvil). Deploys mock registry + AgentDaily,
///         mints a mock Agent ID to the broadcaster, then mints a badge and
///         checks in once. NOT for mainnet/testnet deployment.
contract DeployLocal is Script {
    function run() external {
        vm.startBroadcast();
        MockAgentId registry = new MockAgentId();
        registry.mint(msg.sender);
        AgentDaily daily = new AgentDaily(address(registry));
        daily.mintBadge();
        daily.checkIn();
        vm.stopBroadcast();

        console.log("registry:", address(registry));
        console.log("agentDaily:", address(daily));
        console.log("hasBadge:", daily.hasBadge(msg.sender));
        console.log("badgeTokenId:", daily.badgeTokenId(msg.sender));
        console.log("streak:", daily.streakOf(msg.sender));
        console.log("totalBadges:", daily.totalBadges());
        console.log("totalCheckInsAll:", daily.totalCheckInsAll());
    }
}

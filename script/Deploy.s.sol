// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MilestoneEscrow} from "../src/MilestoneEscrow.sol";

/// Deploys one escrow. Configure with environment variables:
///   FREELANCER, ARBITER, MILESTONES, DURATION_DAYS, DEPOSIT_WEI
/// Local:   forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key <anvil key>
/// Sepolia: forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --account <keystore name>
contract Deploy is Script {
    function run() external returns (MilestoneEscrow escrow) {
        address payable freelancer = payable(vm.envAddress("FREELANCER"));
        address arbiter = vm.envAddress("ARBITER");
        uint256 count = vm.envOr("MILESTONES", uint256(3));
        uint256 durationDays = vm.envOr("DURATION_DAYS", uint256(30));
        uint256 deposit = vm.envOr("DEPOSIT_WEI", uint256(0.003 ether));

        vm.startBroadcast();
        escrow = new MilestoneEscrow{value: deposit}(freelancer, arbiter, count, durationDays);
        vm.stopBroadcast();

        console.log("MilestoneEscrow deployed at", address(escrow));
    }
}

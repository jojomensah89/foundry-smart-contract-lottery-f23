// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";



contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();

        (,, address vrfCoordinator,,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerKey) public returns (uint64) {
        console.log("Creating subscription on ChainId: ", block.chainid);

        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your subdId is:", subId);
        console.log("Update Your subId in helperConfig.s.ol");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address raffle, address vrfCoordinator, uint64 subId, uint256 deployerKey) public {
        console.log("Adding Consumer contract :", raffle);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("On ChainId:", block.chainid);

        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address mostRecentlydeployedRaffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinator,, uint64 subId,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        addConsumer(mostRecentlydeployedRaffle, vrfCoordinator, subId, deployerKey);
    }

    function run() external {
        address mostRecentlydeployedRaffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlydeployedRaffle);
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;
    uint96 public constant FUND_AMOUNT_SEPOLIA = 3 ether;
    uint256 constant ANVIL_CHAINID = 31337;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();

        (,, address vrfCoordinator,, uint64 subscriptionId,, address link, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subscriptionId, link, deployerKey);
    }

    function fundSubscription(address vrfCoordinator, uint64 subscriptionId, address link, uint256 deployerKey)
        public
    {
        console.log("Funding subscription:", subscriptionId);
        console.log("Using vrfCoordinator", vrfCoordinator);
        console.log("On ChainId", block.chainid);
        if (block.chainid == ANVIL_CHAINID) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            // console.log(deployerKey);
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

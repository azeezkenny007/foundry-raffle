// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "./HelperConfig.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract CreateSubscriptions is Script {
    function run() external {
        createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        (uint256 subId,) = createSubcription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function createSubcription(address vrfCoordinator) public returns (uint256, address) {
        console.log("creating subscription on chainId :", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("----------------------------------------------");
        console.log("Subscription ID: ", subId);
        console.log("Subscription created on chainId :", block.chainid);
        return (subId, vrfCoordinator);
    }
}

contract FundSubscriptions is Script, CodeConstants {
    function run() external {
        fundSubscriptionsUsingConfig();
    }

    function fundSubscriptionsUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address link = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator, subscriptionId, link);
    }

    function fundSubscription(address vrfCoordinator, uint256 subScriptionId, address linkToken) public {
        console.log("Funding subscription on chainId :", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subScriptionId, SUBSCRIPTION_FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, SUBSCRIPTION_FUND_AMOUNT, abi.encode(subScriptionId));
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function run() external {
        address mostRecentDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentDeployed);
    }

    function addConsumerUsingConfig(address mostRecntlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address link = helperConfig.getConfig().link;
        addConsumer(mostRecntlyDeployed, vrfCoordinator, subscriptionId);
    }

    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subScriptionId) public {
        console.log("Adding consumer to subscription on chainId :", block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subScriptionId, contractToAddToVrf);
        vm.stopBroadcast();
        console.log("----------------------------------------------");
        console.log("Consumer added to subscription ID: ", subScriptionId);
        console.log("Consumer added to subscription on chainId :", block.chainid);
        console.log("Consumer contract address: ", contractToAddToVrf);
        console.log("VRF Coordinator address: ", vrfCoordinator);
        console.log("Subscription ID: ", subScriptionId);
    }
}

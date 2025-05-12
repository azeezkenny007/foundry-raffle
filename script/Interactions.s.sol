// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "./HelperConfig.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract CreateSubscriptions is Script {
    function run() external returns (uint256, address) {
        createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfigByChainId(block.chainid).account;
        return createSubcription(vrfCoordinator, account);
    }

    function createSubcription(address vrfCoordinator, address account) public returns (uint256, address) {
        console.log("creating subscription on chainId :", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("----------------------------------------------");
        console.log("Subscription ID: ", subId);
        console.log("Subscription created on chainId :", block.chainid);
        return (subId, vrfCoordinator);
    }
}

contract FundSubscriptions is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 2 ether;

    function run() external {
        fundSubscriptionsUsingConfig();
    }

    function fundSubscriptionsUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        //  if (config.subscriptionId == 0) {
        //     CreateSubscriptions createSub = new CreateSubscriptions();
        //     (uint256 updatedSubId, address updatedVRFv2) = createSub.createSubscriptionUsingConfig();
        //     config.subscriptionId = updatedSubId;
        //     config.vrfCoordinator = updatedVRFv2;
        //     console.log("New SubId Created! ", config.subscriptionId, "VRF Address: ", config.vrfCoordinator);
        // }
        // if (config.link == address(0)) {
        //     LinkToken linkToken = new LinkToken();
        //     config.link = address(linkToken);
        // }
        // if (config.account == address(0)) {
        //     config.account = msg.sender;
        // }

        fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subScriptionId, address linkToken, address account)
        public
    {
        // console.log("Funding subscription on chainId :", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subScriptionId, SUBSCRIPTION_FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(linkToken).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(linkToken).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(account);
            console.log("Funding subscription Id with the subscription Id: ", subScriptionId);
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
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecntlyDeployed, vrfCoordinator, subscriptionId, account);
    }

    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subScriptionId, address account)
        public
    {
        console.log("Adding consumer to subscription on chainId :", block.chainid);
        vm.startBroadcast(account);
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

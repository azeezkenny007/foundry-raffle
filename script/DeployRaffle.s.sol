// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscriptions, FundSubscriptions, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address account = config.account;

        if (config.subscriptionId == 0) {
            CreateSubscriptions createSubscription = new CreateSubscriptions();
            (config.subscriptionId, config.vrfCoordinator) = createSubscription.createSubcription(config.vrfCoordinator,config.account);

            //    come and check here later for testnet deployments

            FundSubscriptions fundSubscription = new FundSubscriptions();
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link,config.account);
        }

        vm.startBroadcast(account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId,account);

        return (raffle, helperConfig);
    }
}

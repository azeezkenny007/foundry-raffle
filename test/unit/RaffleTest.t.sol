// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";

abstract contract TestConfig {
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
}

contract RaffleTest is Test, TestConfig {
    Raffle public raffle;
    HelperConfig public helperConfig;
    address public player;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        player = makeAddr("player");
        vm.deal(player, STARTING_BALANCE);
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
    }

    function testRaffleStartedWithOpenState() external view {
        assertEq(uint256(raffle.getRaffleState()), 0);
    }

    function testRaffleRevertsWhenNotEnoughEthSent() external {
        vm.prank(player);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function testPlayerIsRecordedWhenEntered() external {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        address playerAddress = raffle.getPlayer(0);
        assertEq(playerAddress, player);
    }

    function testUserBalanceIsReducedWhenEntered() external {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        uint256 playerBalance = player.balance;
        assertEq(playerBalance, STARTING_BALANCE - entranceFee);
    }

    function testEmitAfterEnteringRaffle() external {
        vm.prank(player);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(player);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowEntranceWhenRaffleIsCalculating() external {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
    }
}

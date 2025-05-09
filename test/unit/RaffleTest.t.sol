// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";

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

    ///////////////////////////////////////////////
    // Initial State Tests
    ///////////////////////////////////////////////
    function testRaffleStartedWithOpenState() external view {
        assertEq(uint256(raffle.getRaffleState()), 0);
    }

    ///////////////////////////////////////////////
    // Raffle Entry Tests
    ///////////////////////////////////////////////
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

    ///////////////////////////////////////////////
    // Upkeep Tests
    ///////////////////////////////////////////////
    function testToCheckUpkeepReturnsFalse() external {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testToCheckRUpkeepReturnsFalseIfRaffleNotOpen() external {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testUpkeepRevertsIfNotNeeded() external {
        uint256 currentBalance = 0;
        uint256 numOfPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numOfPlayers, rState)
        );
        raffle.performUpkeep("");
    }

    ///////////////////////////////////////////////
    // Getter Tests
    ///////////////////////////////////////////////
    function testToCheckTheEntranceFee() external view {
        assertEq(raffle.getEntranceFee(), entranceFee);
    }

    function testNumberOfPlayersThatEnteredRaffle() external {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        address payable[] memory players = raffle.getNumberOfPlayers();
        uint256 numOfPlayers = players.length;
        assertEq(numOfPlayers, 1);
    }

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() external {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdateRaffleStateAndEmitRequestId() external{
         vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpkeep("");

        // Get the logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.log(entries);

    }

    }
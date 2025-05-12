// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract TestConfig {
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
}

contract RaffleTest is Test, TestConfig, CodeConstants {
    ///////////////////////////////////////////////
    // State Variables
    ///////////////////////////////////////////////
    Raffle public raffle;
    HelperConfig public helperConfig;
    address public player;

    ///////////////////////////////////////////////
    // Events
    ///////////////////////////////////////////////
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    ///////////////////////////////////////////////
    // Modifiers
    ///////////////////////////////////////////////
    modifier raffleEntered() {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    ///////////////////////////////////////////////
    // Setup
    ///////////////////////////////////////////////
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

    function testDontAllowEntranceWhenRaffleIsCalculating() external raffleEntered {
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
    }

    ///////////////////////////////////////////////
    //             Upkeep Tests
    ///////////////////////////////////////////////

    function testToCheckUpkeepReturnsFalse() external {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testToCheckRUpkeepReturnsFalseIfRaffleNotOpen() external raffleEntered {
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

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() external raffleEntered {
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdateRaffleStateAndEmitRequestId() external raffleEntered {
        vm.recordLogs();
        raffle.performUpkeep("");
        // Get the logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assertTrue(uint256(requestId) > 0);
        assertEq(uint256(raffleState), 1);
    }

    function testFulfillRandomWordsCanOnlyBeCalledIfPerformUpkeepIsTrue(uint256 randomWords)
        external
        raffleEntered
        skipFork
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomWords, address(raffle));
    }

    function testFulfillRandomwordsPicksAwinnerResetAndSendMoney() external raffleEntered skipFork {
        uint256 startingIndex = 0;
        uint256 numberOfPlayers = 3;
        // address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < numberOfPlayers; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        // vm.deal(address(raffle), 30 ether);

        // console.log("Contract balance before fulfill: ", address(raffle).balance);

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        // uint256 expectedWinnerBalance = expectedWinner.balance;
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        console.log("Request ID: ", uint256(requestId));
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        address recentWinner = raffle.getRecentWinner();
        uint256 raffleState = uint256(raffle.getRaffleState());
        uint256 numOfPlayers = raffle.getNumberOfPlayers().length;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 recentWinnerBalance = recentWinner.balance;
        uint256 prize = entranceFee * (numOfPlayers + 1);

        assert(raffleState == 0);
        assert(numOfPlayers == 0);
        assert(endingTimeStamp > startingTimeStamp);
        assert(requestId > 0);
    }
}

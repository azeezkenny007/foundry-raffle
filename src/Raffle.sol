

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/// @title A sample Raffle contract
/// @author Okhamena Azeez
/// @notice The contract carryouts the Raffle
/// @dev Utilizes Chainlink VRF
contract Raffle is VRFConsumerBaseV2Plus{
    error Raffle__NotEnoughEthSent();
   
    /// @notice The number of confirmations to wait for the VRF to return a random number
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    /// @notice The number of random words to return
    uint32 private constant NUM_WORDS = 1;

    /// @notice The entrance fee to enter the raffle
    uint256 private immutable i_entranceFee;
    /// @notice The interval at which the raffle can be picked
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_gasLane;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;

    event RaffleEntered(address indexed player);

    constructor(uint256 entranceFee, uint256 interval, address _vrfCoordinator, bytes32 _gasLane,uint256 _subscriptionId, uint32 _callbackGasLimit) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_gasLane = _gasLane;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function pickWinner() external  {
       if(block.timestamp < s_lastTimeStamp + i_interval) {
        revert();
       }

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
                        keyHash: i_gasLane,
                        subId: i_subscriptionId,
                        requestConfirmations: REQUEST_CONFIRMATIONS,
                        callbackGasLimit: i_callbackGasLimit,
                        numWords: NUM_WORDS,
                        // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                        extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
                    });


        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            request
        );
    }

     function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal  override{}

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }
}

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A simple Raffle Contract
 * @author Ebenezer Jojo Mensah
 * @notice This contract is for creating a simple raffle
 * @dev Implements Chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2 {
    /**
     * Errors
     */
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

    /**
     * Type Declarations
     */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /**
     * State Variables
     */
    // Block confirmations = REQUEST_CONFIRMATIONS
    uint16 private constant BLOCK_CONFIRMATIONS = 3;
    // Number of Random Numbers = NUM_WORDS
    uint32 private constant NUMBER_WORDS = 1;

    // minimum fee
    uint256 private immutable i_entranceFee;
    // vrf coordinator for a paricular blockchain
    VRFCoordinatorV2Interface private immutable i_vrfCoordiantor;
    //Raffle interval: Duration of Lottery in seconds
    uint256 private immutable i_intervalInSeconds;
    // gasLane/keyHash
    bytes32 immutable i_gasLane;
    // subscription Id from Chainlink
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callBackGasLimit;

    // Dynamic Array of Raffle Participants
    address payable[] private s_players;
    //Last timeStamp in seconds
    uint256 private s_lastTimeStamp;
    // Recent Winner
    address private s_recentWinner;
    // raffle state
    RaffleState private s_raffleState;

    /**
     * Events
     */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 intervalInSeconds,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callBackGasLimit
    )
        /**
         * VRFConsumerBaseV2 inherited contract has a constructor and we put that here
         */
        VRFConsumerBaseV2(vrfCoordinator)
    {
        i_entranceFee = entranceFee;
        i_intervalInSeconds = intervalInSeconds;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordiantor = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callBackGasLimit = callBackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This is the functon that the Chainlink Automation nodes call to see if it's time to perform an upkeep
     * The following should be true for this to return true:
     * 1. The time interval has passed beterrn raflle runs
     * 2. The raffle is in the open state
     * 3. The contract has Eth (aka, players)
     * 4 (Implicit)  The subscription  is funded with LINK
     */

    function checkUpkeep(bytes memory)
        /**
         * checkData
         */
        public
        view
        returns (bool upkeepNeeded, bytes memory)
    /**
     * performData
     */
    {
        //Check to see it enough time has passed
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_intervalInSeconds;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata)
        /**
         * performData
         */
        external
    {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        // check to see if enough time has passed
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordiantor.requestRandomWords(
            i_gasLane, i_subscriptionId, BLOCK_CONFIRMATIONS, i_callBackGasLimit, NUMBER_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    // CEI: Checks, Effects, Interactions(Interactions with Other contracts)
    function fulfillRandomWords(uint256 /*requestId*/, uint256[] memory randomWords) internal override {
        // Checks
        //Effects
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);

        //Interactions
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter functions
     */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumberOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}

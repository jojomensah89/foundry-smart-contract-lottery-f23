// Unit
// Integration
// forked run on testnet
// Staging Run on both testnets and Mainnets

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /**
     * Events
     */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 intervalInSeconds;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callBackGasLimit;
    address link;
    uint256 deployerKey;

    address PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 100 ether;
    uint256 public constant LESS_THAN_ENTRANCE_FEE = 0.001 ether;
    uint256 constant SEND_VALUE = 0.01 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (entranceFee, intervalInSeconds, vrfCoordinator, gasLane, subscriptionId, callBackGasLimit, link,) =
            helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleIntializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //// enter Raffle ///
    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);

        raffle.enterRaffle{value: LESS_THAN_ENTRANCE_FEE}();
    }

    function testRaffleFailsWithNoFunds() public {
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);

        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        uint256 StartingNumberOfPlayers;
        uint256 currentNumberOfPlayers;

        StartingNumberOfPlayers = raffle.getNumberOfPlayers();

        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();

        currentNumberOfPlayers = raffle.getNumberOfPlayers();

        assertEq(StartingNumberOfPlayers, 0);
        assertEq(currentNumberOfPlayers, 1);
        assertEq(raffle.getPlayer(0), PLAYER);
    }

    function testEmitsEventOnRaffleEntrance() public {
        vm.expectEmit(true, false, false, false, address(raffle));

        emit EnteredRaffle(PLAYER);

        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // vm.warp sets block.timestamp
        vm.warp(block.timestamp + intervalInSeconds + 1);

        // vm.roll sets block number
        vm.roll(block.number + 2);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    /// Checkupkeep
    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        // vm.warp sets block.timestamp
        vm.warp(block.timestamp + intervalInSeconds + 1);
        // vm.roll sets block number
        vm.roll(block.number + 2);

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // vm.warp sets block.timestamp
        vm.warp(block.timestamp + intervalInSeconds + 1);
        // vm.roll sets block number
        vm.roll(block.number + 2);
        raffle.performUpkeep("");
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    // testCheckUpKeepReturnsFalseIfenoughTimeHasntPassed
    function testCheckUpKeepReturnsFalseIfenoughTimeHasntPassed() public {
        // vm.expectRevert();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertEq(upkeepNeeded, false);
    }

    // testCheckUpKeepReturnsTrueWhenParametersAreGood

    function testCheckUpKeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // vm.warp sets block.timestamp
        vm.warp(block.timestamp + intervalInSeconds + 2);
        // vm.roll sets block number
        vm.roll(block.number + 2);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(upkeepNeeded);
    }

    //// PerformUpkeep Tests
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        //Arange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // vm.warp sets block.timestamp
        vm.warp(block.timestamp + intervalInSeconds + 1);
        // vm.roll sets block number
        vm.roll(block.number + 2);

        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        //Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, currentBalance, numPlayers, raffleState)
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAndTimePassed {
        //Arrange

        //Act
        vm.recordLogs(); // Records All events/emit

        raffle.performUpkeep(""); // emits requestId

        // Vm.Log is a special type for events in foundry
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(rState) > 0);

        assert(uint256(requestId) > 0);
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        skipFork
        raffleEnteredAndTimePassed
    {
        // Arrange
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFullfillRandomWordsPicksAWinnerResetsAndSendsMoney() public skipFork raffleEnteredAndTimePassed {
        //Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 prize = entranceFee * (additionalEntrants + 1);

        // pretend to be chainlink vrf to get random number and pick winner
        vm.recordLogs(); // Records All events/emit
        raffle.performUpkeep(""); // emits requestId
        // Vm.Log is a special type for events in foundry
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        //Assert
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(uint256(raffle.getNumberOfPlayers()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLastTimeStamp() == block.timestamp);
        assert(address(raffle).balance == 0);
        assert(raffle.getRecentWinner().balance == (STARTING_USER_BALANCE - entranceFee) + prize);
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // vm.warp sets block.timestamp
        vm.warp(block.timestamp + intervalInSeconds + 1);
        // vm.roll sets block number
        vm.roll(block.number + 2);
        _;
    }
}

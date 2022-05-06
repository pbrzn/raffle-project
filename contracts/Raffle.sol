// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

error Raffle__SendMoreToEnterRaffle();
error Raffle__RaffleNotOpen();
error Raffle_UpkeepNotNeeded();
error Raffle__TransferFailed();

contract Raffle is VRFConsumerBaseV2 {
  enum RaffleState {
    Open,
    Calculating
  }
  RaffleState public s_raffleState;
  uint256 public immutable i_entranceFee;
  uint256 public immutable i_interval;
  address payable[] public s_players;
  uint256 public s_lastTimeStamp;
  VRFCoordinatorV2Interface public immutable i_vrfCoordinator;
  bytes32 public i_gasLane;
  uint64 public i_subscriptionId;
  uint32 public i_callbackGasLimit;
  address public s_recentWinner;
 
  uint16 public constant REQUEST_CONFIRMATIONS = 3;
  uint32 public constant NUM_WORDS = 1;

  event RaffleEnter(address indexed player);
  event RequestedRaffleWinner(uint256 indexed requestId);
  event winnerPicked(address indexed winner);

  constructor(
    uint256 entranceFee,
    uint256 interval,
    address vrfCoordinatorV2,
    bytes32 gasLane, //keyhash
    uint64 subscriptionId,
    uint32 callbackGasLimit
  ) VRFConsumerBaseV2(vrfCoordinatorV2) {
    i_entranceFee = entranceFee;
    i_interval = interval;
    s_lastTimeStamp = block.timestamp;
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
    i_gasLane = gasLane;
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;
  }

  function enterRaffle() external payable {
    if (msg.value < i_entranceFee) {
      revert Raffle__SendMoreToEnterRaffle();
    }
    if (s_raffleState != RaffleState.Open) {
      revert Raffle__RaffleNotOpen();
    }
    s_players.push(payable(msg.sender));
    emit RaffleEnter(msg.sender);
  }

  function checkUpkeep(
    bytes memory /* checkData */
  )
    public
    view
    returns(
      bool upkeepNeeded,
      bytes memory /* performData */
    )
  {
    bool isOpen = RaffleState.Open == s_raffleState;
    bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
    bool hasBalance = address(this).balance > 0;
    bool hasPlayers = s_players.length > 0;
    upkeepNeeded = (timePassed && isOpen && hasBalance && hasPlayers);
    return (upkeepNeeded, "0x0");
  }

  function performUpkeep(
    bytes calldata /* performData */
  ) external {
    (bool upkeepNeeded, ) = checkUpkeep("");
    if (!upkeepNeeded) {
      revert Raffle_UpkeepNotNeeded();
    }
    s_raffleState = RaffleState.Calculating;
    uint256 requestId = i_vrfCoordinator.requestRandomWords(
      i_gasLane,
      i_subscriptionId,
        REQUEST_CONFIRMATIONS,
        i_callbackGasLimit,
        NUM_WORDS
    );
    emit RequestedRaffleWinner(requestId);
  }

  function fulfillRandomWords(
    uint256, /* requesteId */
    uint256[] memory randomWords
  ) internal override {
    uint256 indexOfWinner = randomWords[0] % s_players.length;
    address payable recentWinner = s_players[indexOfWinner];
    s_recentWinner = recentWinner;
    s_players = new address payable[](0);
    s_raffleState = RaffleState.Open;
    s_lastTimeStamp = block.timestamp;
    (bool success, ) = recentWinner.call{ value: address(this).balance}("");
    // using call instead of send for transfers is preferred by Chainlink
    if (!success) {
      revert Raffle__TransferFailed();
    }
    emit winnerPicked(recentWinner);
  }
}

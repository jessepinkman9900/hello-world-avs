// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Initializable} from "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import {Pausable, IPauserRegistry} from "@eigenlayer/contracts/permissions/Pausable.sol";
import {BLSSignatureChecker} from "@eigenlayer-middleware/src/BLSSignatureChecker.sol";
import {IRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {OperatorStateRetriever} from "@eigenlayer-middleware/src/OperatorStateRetriever.sol";
import {ISquaringTaskManager} from "./ISquaringTaskManager.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";

import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";

contract SquaringTaskManager is
  Initializable,
  OwnableUpgradeable,
  Pausable,
  BLSSignatureChecker,
  OperatorStateRetriever,
  ISquaringTaskManager
{
  using BN254 for BN254.G1Point;

  // constant
  uint32 public immutable TASK_RESPONSE_WINDOW_BLOCK;
  uint32 public constant TASK_CHALLENGE_WINDOW_BLOCK = 100;
  uint256 internal constant THRESHOLD_DENOMINATOR = 100;

  // state
  uint32 public latestTaskNumber;
  mapping(uint32 => bytes32) public allTaskHashes;
  mapping(uint32 => bytes32) public allTaskResponses;
  mapping(uint32 => bool) public taskSuccessfullyChallenged;

  address public aggregator;
  address public generator;

  // modifier
  modifier onlyAggergator() {
    require(msg.sender == aggregator, "Aggregator must be the caller");
    _;
  }

  modifier onlyTaskGenerator() {
    require(msg.sender == generator, "Generator must be the caller");
    _;
  }

  // constructor
  constructor(
    IRegistryCoordinator _registryCoordinator,
    uint32 _taskResponseWindowBlock,
    IPauserRegistry _pauserRegistry
  ) BLSSignatureChecker(_registryCoordinator) Pausable(_pauserRegistry) {
    TASK_RESPONSE_WINDOW_BLOCK = _taskResponseWindowBlock;
  }

  // function
  function initialize(
    address _initialOwner,
    address _aggregator,
    address _generator
  ) public initializer {
    _transferOwnership(_initialOwner);
    _setAggregator(_aggregator);
    _setGenerator(_generator);
  }

  function setAggregator(
    address newAggregator
  ) external onlyOwner {
    _setAggregator(newAggregator);
  }

  function setGenerator(
    address newGenerator
  ) external onlyOwner {
    _setGenerator(newGenerator);
  }

  function createNewTask(
    uint256 numberToBeSquared,
    uint32 quorumThresholdPercentage,
    bytes calldata quorumNumbers
  ) external onlyTaskGenerator {
    // new task
    Task memory newTask = Task({
      numberToBeSquared: numberToBeSquared,
      taskCreatedBlockNumber: uint32(block.number),
      quorumNumbers: quorumNumbers,
      quorumThresholdPercentage: quorumThresholdPercentage
    });

    // store hash of task on chain
    allTaskHashes[latestTaskNumber] = keccak256(abi.encode(newTask));

    // emit event
    emit NewTaskCreated(latestTaskNumber, newTask);

    // increment task number
    latestTaskNumber += 1;
  }

  function responsdToTask(
    Task calldata task,
    TaskResponse calldata taskResponse,
    NonSignerStakesAndSignature memory nonSignerStakesAndSignature
  ) external onlyAggergator {
    // validate task is valid, yet to be responded to, responded to in time
    require(
      keccak256(abi.encode(task)) == allTaskHashes[taskResponse.referenceTaskIndex],
      "supplied task does not match task hash recorded in contract"
    );
    require(
      allTaskResponses[taskResponse.referenceTaskIndex] == bytes32(0),
      "aggregator has already responded to task"
    );
    require(
      uint32(block.number) <= task.taskCreatedBlockNumber + TASK_RESPONSE_WINDOW_BLOCK,
      "task response window has expired"
    );

    // checking signature & threshold criteria satisfied or not
    // calculate message which operators signed
    bytes32 message = keccak256(abi.encode(taskResponse));

    // check BLS Signature
    (QuorumStakeTotals memory quorumStakeTotals, bytes32 hashOfNonSigners) = checkSignatures(
      message, task.quorumNumbers, task.taskCreatedBlockNumber, nonSignerStakesAndSignature
    );

    // check signatures own atleast threshold percentage of each quorum
    for (uint256 i = 0; i < task.quorumNumbers.length; i++) {
      require(
        quorumStakeTotals.signedStakeForQuorum[i] * THRESHOLD_DENOMINATOR
          >= quorumStakeTotals.totalStakeForQuorum[i] * uint8(task.quorumThresholdPercentage),
        "signatures do not own at least threshold percentage of a quorum"
      );
    }

    TaskResponseMetadata memory taskResponseMetadata = TaskResponseMetadata({
      taskRespondedBlockNumber: uint32(block.number),
      hashOfNonSigners: hashOfNonSigners
    });
    allTaskResponses[taskResponse.referenceTaskIndex] =
      keccak256(abi.encode(taskResponse, taskResponseMetadata));

    // emit event
    emit TaskRespondedTo(taskResponse, taskResponseMetadata);
  }

  function raiseAndResolveChallenge(
    Task calldata task,
    TaskResponse calldata taskResponse,
    TaskResponseMetadata calldata taskResponseMetadata,
    BN254.G1Point[] memory pubkeyOfNonSigningOperators
  ) external {}

  function taskNumber() external view returns (uint32) {
    return latestTaskNumber;
  }

  function getTaskResponseWindowBlock() external view returns (uint32) {
    return TASK_RESPONSE_WINDOW_BLOCK;
  }

  function _setGenerator(
    address newGenerator
  ) internal {
    address oldGenerator = generator;
    generator = newGenerator;
    emit GeneratorUpdfated(oldGenerator, newGenerator);
  }

  function _setAggregator(
    address newAggregator
  ) internal {
    address oldAggregator = aggregator;
    aggregator = newAggregator;
    emit AggregatorUpdated(oldAggregator, newAggregator);
  }
}

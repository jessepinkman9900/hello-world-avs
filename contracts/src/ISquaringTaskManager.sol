// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {BN254} from "@eigenlayer-middleware/src/libraries/BN254.sol";

interface ISquaringTaskManager {
  // event
  event NewTaskCreated(uint32 indexed taskIndex, Task task);
  event TaskRespondedTo(TaskResponse taskResponse, TaskResponseMetadata taskResponseMetadata);
  event TaskCompleted(uint32 indexed taskIndex);
  event TaskChallengedSuccessfully(uint32 indexed taskIndex, address indexed callenger);
  event TaskChallengedUnsuccessfully(uint32 indexed taskIndex, address indexed callenger);
  event AggregatorUpdated(address indexed oldAggregator, address indexed newAggregator);
  event GeneratorUpdfated(address indexed oldGenerator, address indexed newGenerator);

  // struct
  struct Task {
    uint256 numberToBeSquared;
    uint32 taskCreatedBlockNumber;
    bytes quorumNumbers;
    uint32 quorumThresholdPercentage;
  }

  struct TaskResponse {
    uint32 referenceTaskIndex;
    uint256 numberSquared;
  }

  struct TaskResponseMetadata {
    uint32 taskRespondedBlockNumber;
    bytes32 hashOfNonSigners;
  }

  // function
  function createNewTask(
    uint256 numberToBeSquared,
    uint32 quorumThresholdPercentage,
    bytes calldata quorumNumbers
  ) external;
  function taskNumber() external view returns (uint32);
  function raiseAndResolveChallenge(
    Task calldata task,
    TaskResponse calldata taskResponse,
    TaskResponseMetadata calldata taskResponseMetadata,
    BN254.G1Point[] memory pubkeyOfNonSigningOperators
  ) external;
  function getTaskResponseWindowBlock() external view returns (uint32);
}

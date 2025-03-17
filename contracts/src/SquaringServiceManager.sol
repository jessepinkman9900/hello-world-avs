// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {BytesLib} from "@eigenlayer/contracts/libraries/BytesLib.sol";
import {ServiceManagerBase} from "@eigenlayer-middleware/src/ServiceManagerBase.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {IRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {IStakeRegistry} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {IPermissionController} from "@eigenlayer/contracts/interfaces/IPermissionController.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {ISquaringTaskManager} from "./ISquaringTaskManager.sol";

contract SquaringServiceManager is ServiceManagerBase {
  using BytesLib for bytes;

  ISquaringTaskManager public immutable taskManager;

  // modifier
  modifier onlyTaskManager() {
    require(
      msg.sender == address(taskManager), "SquaringServiceManager: caller is not the task manager"
    );
    _;
  }

  // constructor
  constructor(
    IAVSDirectory _avsDirectory,
    IRewardsCoordinator _rewardsCoordinator,
    IRegistryCoordinator _registryCoordinator,
    IStakeRegistry _stakeRegistry,
    IPermissionController _permissionController,
    IAllocationManager _allocationManager,
    ISquaringTaskManager _squaringTaskManager
  )
    ServiceManagerBase(
      _avsDirectory,
      _rewardsCoordinator,
      _registryCoordinator,
      _stakeRegistry,
      _permissionController,
      _allocationManager
    )
  {
    taskManager = _squaringTaskManager;
  }

  function initialize(address initialOwner, address rewardsInitiator) external initializer {
    __ServiceManagerBase_init(initialOwner, rewardsInitiator);
  }

  function freezeOperator(
    address operator
  ) external onlyTaskManager {
    // todo
  }
}

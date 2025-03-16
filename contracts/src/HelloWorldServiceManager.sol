// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ECDSAServiceManagerBase} from
    "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";

import {ECDSAUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC1271Upgradeable} from
    "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";

import {IHelloWorldServiceManager} from "./IHelloWorldServiceManager.sol";


import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {TransparentUpgradeableProxy} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract HelloWorldServiceManager is ECDSAServiceManagerBase, IHelloWorldServiceManager {
    using ECDSAUpgradeable for bytes32;

    // state variables
    uint32 public latestTaskNumber;
    mapping(uint32 => bytes32) public allTaskHashes;
    mapping(address => mapping(uint32 => bytes)) public allTaskResponses;

    // modifiers
    modifier onlyOperator() {
        require(
            ECDSAStakeRegistry(stakeRegistry).operatorRegistered(msg.sender),
            "Operator must be the caller"
        );
        _;
    }

    // constructor
    constructor(
        address _avsDirectory,
        address _stakeRegistry,
        address _rewardsCoordinator,
        address _delegationManager,
        address _allocationManager
    )
        ECDSAServiceManagerBase(
            _avsDirectory,
            _stakeRegistry,
            _rewardsCoordinator,
            _delegationManager,
            _allocationManager
        )
    {}

    function initialize(address initialOwner, address rewardsInitiator) external initializer {
        __ServiceManagerBase_init(initialOwner, rewardsInitiator);
    }

    // impl IServiceManager
    function addPendingAdmin(
        address admin
    ) external onlyOwner {}
    function removePendingAdmin(
        address pendingAdmin
    ) external onlyOwner {}
    function removeAdmin(
        address admin
    ) external onlyOwner {}
    function setAppointee(address appointee, address target, bytes4 selector) external onlyOwner {}
    function removeAppointee(
        address appointee,
        address target,
        bytes4 selector
    ) external onlyOwner {}
    function deregisterOperatorFromOperatorSets(
        address operator,
        uint32[] memory operatorSetIds
    ) external {}

    // impl IHelloWorldServiceManager
    function createNewTask(
        string memory name
    ) external returns (Task memory) {
        // create new task
        Task memory newTask = Task({
            name: name,
            taskCreatedBlock: uint32(block.number)
        });

        // store hash of task on chain
        allTaskHashes[latestTaskNumber] = keccak256(abi.encode(newTask));

        // increment taskNumber
        latestTaskNumber++;

        // emit event
        emit NewTaskCreated(latestTaskNumber, newTask);

        return newTask;
    }

    function respondToTask(
        Task calldata task,
        uint32 referenceTaskIndex,
        bytes calldata signature
    ) external {
        // check task is valid, has not been responded to, being responded to in time
        require(
            keccak256(abi.encode(task)) == allTaskHashes[referenceTaskIndex],
            "supplied task does not match task hash recorded in contract"
        );
        require(
            allTaskResponses[msg.sender][referenceTaskIndex].length == 0,
            "operator has already responded to this task"
        );

        // validate signature
        bytes32 messageHash = keccak256(abi.encodePacked("Hello, ", task.name));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        bytes4 magicValue = IERC1271Upgradeable.isValidSignature.selector;
        bytes4 isValidSignatureResult =
            ECDSAStakeRegistry(stakeRegistry).isValidSignature(ethSignedMessageHash, signature);
        require(magicValue == isValidSignatureResult, "signature is not valid");

        // updating storage with task response
        allTaskResponses[msg.sender][referenceTaskIndex] = signature;

        // emit event
        emit TaskResponded(referenceTaskIndex, task, msg.sender);
    }
}

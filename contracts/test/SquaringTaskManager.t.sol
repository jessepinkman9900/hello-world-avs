// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {BLSMockAVSDeployer} from "@eigenlayer-middleware/test/utils/BLSMockAVSDeployer.sol";
import {SquaringTaskManager} from "../src/SquaringTaskManager.sol";
import {SquaringServiceManager, IRegistryCoordinator} from "../src/SquaringServiceManager.sol";
import {TransparentUpgradeableProxy} from
  "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SquaringTaskManagerTest is BLSMockAVSDeployer {
  SquaringServiceManager squaringServiceManager;
  SquaringServiceManager squaringServiceManagerImplementation;
  SquaringTaskManager squaringTaskManager;
  SquaringTaskManager squaringTaskManagerImplementation;

  uint32 public constant TASK_RESPONSE_WINDOW_BLOCK = 30;
  address aggregator = address(uint160(uint256(keccak256(abi.encodePacked("aggregator")))));
  address generator = address(uint160(uint256(keccak256(abi.encodePacked("generator")))));

  function setUp() public {
    _setUpBLSMockAVSDeployer();

    squaringTaskManagerImplementation = new SquaringTaskManager(
      IRegistryCoordinator(address(registryCoordinator)), TASK_RESPONSE_WINDOW_BLOCK, pauserRegistry
    );

    // upgrade proxy contracts to use correct impl contracts and init them
    squaringTaskManager = SquaringTaskManager(
      address(
        new TransparentUpgradeableProxy(
          address(squaringTaskManagerImplementation),
          address(proxyAdmin),
          abi.encodeWithSelector(
            squaringTaskManager.initialize.selector, registryCoordinatorOwner, aggregator, generator
          )
        )
      )
    );
  }

  function testCreateNewTask() public {
    bytes memory quorumNumbers = new bytes(0);
    vm.prank(generator);
    squaringTaskManager.createNewTask(2, 100, quorumNumbers);
    assertEq(squaringTaskManager.latestTaskNumber(), 1);
  }
}

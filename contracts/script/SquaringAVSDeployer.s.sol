// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20Mock} from "../src/ERC20Mock.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {PauserRegistry} from "@eigenlayer/contracts/permissions/PauserRegistry.sol";
import {IPauserRegistry} from "@eigenlayer/contracts/interfaces/IPauserRegistry.sol";
import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {IRegistryCoordinator} from "@eigenlayer-middleware/src/interfaces/IRegistryCoordinator.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";
import {IndexRegistry} from "@eigenlayer-middleware/src/IndexRegistry.sol";
import {StakeRegistry} from "@eigenlayer-middleware/src/StakeRegistry.sol";
import {SocketRegistry} from "eigenlayer-middleware/src/SocketRegistry.sol";
import {
  IBLSApkRegistry,
  IIndexRegistry,
  IStakeRegistry,
  ISocketRegistry
} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {OperatorStateRetriever} from "@eigenlayer-middleware/src/OperatorStateRetriever.sol";
import {StrategyBaseTVLLimits} from "@eigenlayer/contracts/strategies/StrategyBaseTVLLimits.sol";
import {ISquaringTaskManager} from "../src/ISquaringTaskManager.sol";
import {SquaringTaskManager} from "../src/SquaringTaskManager.sol";
import {SquaringServiceManager} from "../src/SquaringServiceManager.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";

import {
  TransparentUpgradeableProxy,
  ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IStrategyManager, IStrategy} from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import {ISlasher} from "@eigenlayer-middleware/src/interfaces/ISlasher.sol";
import {IRewardsCoordinator} from "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {ISlashingRegistryCoordinatorTypes} from
  "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistryTypes} from "@eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {Script} from "forge-std/Script.sol";
import {Utils} from "./utils/Utils.sol";
import {EmptyContract} from "@eigenlayer/test/mocks/EmptyContract.sol";
import {stdJson} from "forge-std/StdJson.sol";

contract SquaringAVSDeployer is Script, Utils {
  // DEPLOYMENT CONSTANTS
  uint256 public constant QUORUM_THRESHOLD_PERCENTAGE = 100;
  uint32 public constant TASK_RESPONSE_WINDOW_BLOCK = 30;
  uint32 public constant TASK_DURATION_BLOCKS = 0;

  address public constant AGGREGATOR_ADDR = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
  address public constant TASK_GENERATOR_ADDR = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;

  // deploye erc20, create strategy for it, whitelist this strat in strategy manager
  ERC20Mock public erc20Mock;
  StrategyBaseTVLLimits public erc20MockStrategy;

  // avs contracts
  ProxyAdmin public squaringProxyAdmin;
  PauserRegistry public squaringPauserRegistry;

  RegistryCoordinator public registryCoordinator;
  IRegistryCoordinator public registryCoordinatorImplementation;

  IBLSApkRegistry public blsApkRegistry;
  IBLSApkRegistry public blsApkRegistryImplementation;

  IIndexRegistry public indexRegistry;
  IIndexRegistry public indexRegistryImplementation;

  IStakeRegistry public stakeRegistry;
  IStakeRegistry public stakeRegistryImplementation;

  ISocketRegistry public socketRegistry;
  ISocketRegistry public socketRegistryImplementation;

  OperatorStateRetriever public operatorStateRetriever;

  SquaringServiceManager public squaringServiceManager;
  IServiceManager public squaringServiceManagerImplementation;

  SquaringTaskManager public squaringTaskManager;
  ISquaringTaskManager public squaringTaskManagerImplementation;

  function run() external {
    // eigenlayer contracts
    string memory eigenlayerDeployedContracts = readOutput("eigenlayer_deployment_output");
    IDelegationManager delegationManager =
      IDelegationManager(stdJson.readAddress(eigenlayerDeployedContracts, ".address.delegation"));
    IAVSDirectory avsDirectory =
      IAVSDirectory(stdJson.readAddress(eigenlayerDeployedContracts, ".address.avsDirectory"));
    IRewardsCoordinator rewardsCoordinator = IRewardsCoordinator(
      stdJson.readAddress(eigenlayerDeployedContracts, ".address.rewardsCoordinator")
    );
    IAllocationManager allocationManager = IAllocationManager(
      stdJson.readAddress(eigenlayerDeployedContracts, ".address.allocationManager")
    );

    address squaringCommunityMultisig = msg.sender;
    address squaringPauser = msg.sender;

    erc20MockStrategy = StrategyBaseTVLLimits(
      stdJson.readAddress(eigenlayerDeployedContracts, ".address.strategies.MockETH")
    );
    erc20Mock = ERC20Mock(address(erc20MockStrategy.underlyingToken()));

    vm.startBroadcast();
    // convert erc20MockStrategy to list
    IStrategy[] memory strategies = new IStrategy[](1);
    strategies[0] = erc20MockStrategy;
    _deploySquaringAVSContracts(
      delegationManager,
      avsDirectory,
      rewardsCoordinator,
      allocationManager,
      strategies,
      squaringCommunityMultisig,
      squaringPauser
    );
    vm.stopBroadcast();
  }

  function _deploySquaringAVSContracts(
    IDelegationManager delegationManager,
    IAVSDirectory avsDirectory,
    IRewardsCoordinator rewardsCoordinator,
    IAllocationManager allocationManager,
    IStrategy[] memory strategies,
    address squaringCommunityMultisig,
    address squaringPauser
  ) internal {
    // deploy proxy admin to be able to upgrade proxy contracts
    squaringProxyAdmin = new ProxyAdmin();

    // deploy pauser registry
    {
      address[] memory pausers = new address[](2);
      pausers[0] = squaringPauser;
      pausers[1] = squaringCommunityMultisig;
      squaringPauserRegistry = new PauserRegistry(pausers, squaringCommunityMultisig);
    }

    _deployProxyContracts();
    operatorStateRetriever = new OperatorStateRetriever();
    _deployImplementationContractsAndUpgrade(
      delegationManager,
      avsDirectory,
      rewardsCoordinator,
      allocationManager,
      strategies,
      squaringCommunityMultisig,
      squaringPauserRegistry
    );

    // write json data
    string memory parent_object = "parent object";
    string memory deployed_addresses = "addresses";
    vm.serializeAddress(deployed_addresses, "erc20Mock", address(erc20Mock));
    vm.serializeAddress(deployed_addresses, "erc20MockStrategy", address(erc20MockStrategy));
    vm.serializeAddress(
      deployed_addresses, "squaringServiceManager", address(squaringServiceManager)
    );
    vm.serializeAddress(
      deployed_addresses,
      "squaringAServiceManagerImplementation",
      address(squaringServiceManagerImplementation)
    );
    vm.serializeAddress(deployed_addresses, "squaringTaskManager", address(squaringTaskManager));
    vm.serializeAddress(
      deployed_addresses,
      "squaringTaskManagerImplementation",
      address(squaringTaskManagerImplementation)
    );
    vm.serializeAddress(deployed_addresses, "registryCoordinator", address(registryCoordinator));
    vm.serializeAddress(
      deployed_addresses,
      "registryCoordinatorImplementation",
      address(registryCoordinatorImplementation)
    );
    vm.serializeAddress(deployed_addresses, "blsApkRegistry", address(blsApkRegistry));
    vm.serializeAddress(
      deployed_addresses, "blsApkRegistryImplementation", address(blsApkRegistryImplementation)
    );
    vm.serializeAddress(deployed_addresses, "indexRegistry", address(indexRegistry));
    vm.serializeAddress(
      deployed_addresses, "indexRegistryImplementation", address(indexRegistryImplementation)
    );
    vm.serializeAddress(deployed_addresses, "stakeRegistry", address(stakeRegistry));
    vm.serializeAddress(
      deployed_addresses, "stakeRegistryImplementation", address(stakeRegistryImplementation)
    );
    vm.serializeAddress(deployed_addresses, "socketRegistry", address(socketRegistry));
    string memory deployed_addresses_output = vm.serializeAddress(
      deployed_addresses, "operatorStateRetriever", address(operatorStateRetriever)
    );

    // serialize
    string memory finalJson =
      vm.serializeString(parent_object, deployed_addresses, deployed_addresses_output);
    writeOutput(finalJson, "squaring_avs_deployment_output");
  }

  function _deployProxyContracts() internal {
    // create empty contract to use while deploying proxy contracts until impl is deployed
    EmptyContract emptyContract = new EmptyContract();

    // deploy proxy contracts
    squaringServiceManager = SquaringServiceManager(
      address(
        new TransparentUpgradeableProxy(address(emptyContract), address(squaringProxyAdmin), "")
      )
    );
    squaringTaskManager = SquaringTaskManager(
      address(
        new TransparentUpgradeableProxy(address(emptyContract), address(squaringProxyAdmin), "")
      )
    );
    registryCoordinator = RegistryCoordinator(
      address(
        new TransparentUpgradeableProxy(address(emptyContract), address(squaringProxyAdmin), "")
      )
    );
    blsApkRegistry = IBLSApkRegistry(
      address(
        new TransparentUpgradeableProxy(address(emptyContract), address(squaringProxyAdmin), "")
      )
    );
    indexRegistry = IIndexRegistry(
      address(
        new TransparentUpgradeableProxy(address(emptyContract), address(squaringProxyAdmin), "")
      )
    );
    stakeRegistry = IStakeRegistry(
      address(
        new TransparentUpgradeableProxy(address(emptyContract), address(squaringProxyAdmin), "")
      )
    );
    socketRegistry = ISocketRegistry(
      address(
        new TransparentUpgradeableProxy(address(emptyContract), address(squaringProxyAdmin), "")
      )
    );
  }

  function _deployImplementationContractsAndUpgrade(
    IDelegationManager _delegationManager,
    IAVSDirectory _avsDirectory,
    IRewardsCoordinator _rewardsCoordinator,
    IAllocationManager _allocationManager,
    IStrategy[] memory _strategies,
    address _squaringCommunityMultisig,
    IPauserRegistry _squaringPauserRegistry
  ) internal {
    // stake registry
    stakeRegistryImplementation =
      new StakeRegistry(registryCoordinator, _delegationManager, _avsDirectory, _allocationManager);
    squaringProxyAdmin.upgrade(
      ITransparentUpgradeableProxy(payable(address(stakeRegistry))),
      address(stakeRegistryImplementation)
    );

    // bls apk registry
    blsApkRegistryImplementation = new BLSApkRegistry(registryCoordinator);
    squaringProxyAdmin.upgrade(
      ITransparentUpgradeableProxy(payable(address(blsApkRegistry))),
      address(blsApkRegistryImplementation)
    );

    // index registry
    indexRegistryImplementation = new IndexRegistry(registryCoordinator);
    squaringProxyAdmin.upgrade(
      ITransparentUpgradeableProxy(payable(address(indexRegistry))),
      address(indexRegistryImplementation)
    );

    // socket registry
    socketRegistryImplementation = new SocketRegistry(registryCoordinator);
    squaringProxyAdmin.upgrade(
      ITransparentUpgradeableProxy(payable(address(socketRegistry))),
      address(socketRegistryImplementation)
    );

    // registry coordinator
    registryCoordinatorImplementation = new RegistryCoordinator(
      IServiceManager(address(squaringServiceManager)),
      IStakeRegistry(address(stakeRegistry)),
      IBLSApkRegistry(address(blsApkRegistry)),
      IIndexRegistry(address(indexRegistry)),
      ISocketRegistry(address(socketRegistry)),
      IAllocationManager(address(_allocationManager)),
      IPauserRegistry(address(squaringPauserRegistry))
    );

    // setup quorums
    {
      uint256 numQuorums = 1;
      uint256 numStrategies = _strategies.length;

      // for each quorum - define QuorunOperatorSetParam, minimumStakeForQuorum, and strategyParams
      IRegistryCoordinator.OperatorSetParam[] memory quorumsOperatorSetParams =
        new IRegistryCoordinator.OperatorSetParam[](numQuorums);
      for (uint256 i = 0; i < numQuorums; i++) {
        // hard code
        quorumsOperatorSetParams[i] = ISlashingRegistryCoordinatorTypes.OperatorSetParam({
          maxOperatorCount: 10_000,
          kickBIPsOfOperatorStake: 15_000,
          kickBIPsOfTotalStake: 100
        });
      }
      // set to 0 for every quorum
      uint96[] memory quorumsMinimumStake = new uint96[](numQuorums);
      IStakeRegistry.StrategyParams[][] memory quorumsStategyParams =
        new IStakeRegistry.StrategyParams[][](numQuorums);
      for (uint256 i = 0; i < numQuorums; i++) {
        quorumsStategyParams[i] = new IStakeRegistry.StrategyParams[](numStrategies);
        for (uint256 j = 0; j < numStrategies; j++) {
          quorumsStategyParams[i][j] =
            IStakeRegistryTypes.StrategyParams({strategy: _strategies[j], multiplier: 1 ether});
        }
      }
      squaringProxyAdmin.upgradeAndCall(
        ITransparentUpgradeableProxy(payable(address(registryCoordinator))),
        address(registryCoordinatorImplementation),
        abi.encodeWithSelector(
          RegistryCoordinator.initialize.selector, // todo: not intialize in registry coordinator
          _squaringCommunityMultisig,
          _squaringCommunityMultisig,
          _squaringCommunityMultisig,
          squaringPauserRegistry,
          0,
          quorumsOperatorSetParams,
          quorumsMinimumStake,
          quorumsStategyParams
        )
      );
    }

    // service manager implementation
    squaringServiceManagerImplementation = new SquaringServiceManager(
      _avsDirectory, _rewardsCoordinator, registryCoordinator, stakeRegistry, squaringTaskManager
    );
    squaringProxyAdmin.upgrade(
      ITransparentUpgradeableProxy(payable(address(squaringServiceManager))),
      address(squaringServiceManagerImplementation)
    );

    // task manager implementation
    squaringTaskManagerImplementation =
      new SquaringTaskManager(registryCoordinator, TASK_RESPONSE_WINDOW_BLOCK);
    squaringProxyAdmin.upgradeAndCall(
      ITransparentUpgradeableProxy(payable(address(squaringTaskManager))),
      address(squaringTaskManagerImplementation),
      abi.encodeWithSelector(
        SquaringTaskManager.initialize.selector,
        _squaringPauserRegistry,
        _squaringCommunityMultisig,
        AGGREGATOR_ADDR,
        TASK_GENERATOR_ADDR
      )
    );
  }
}

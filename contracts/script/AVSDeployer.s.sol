// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {DeployFromScratch} from
  "@eigenlayer-scripts/deploy/local/deploy_from_scratch.slashing.s.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {IAllocationManager} from "@eigenlayer/contracts/interfaces/IAllocationManager.sol";
import {IPermissionController} from "@eigenlayer/contracts/interfaces/IPermissionController.sol";
import {StrategyBaseTVLLimits} from "@eigenlayer/contracts/strategies/StrategyBaseTVLLimits.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {PauserRegistry} from "@eigenlayer/contracts/permissions/PauserRegistry.sol";
import {EmptyContract} from "@eigenlayer/test/mocks/EmptyContract.sol";
import {TransparentUpgradeableProxy} from
  "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {SquaringServiceManager} from "../src/SquaringServiceManager.sol";
import {SquaringTaskManager} from "../src/SquaringTaskManager.sol";
import {ISquaringTaskManager} from "../src/ISquaringTaskManager.sol";
import {RegistryCoordinator} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {BLSApkRegistry} from "@eigenlayer-middleware/src/BLSApkRegistry.sol";
import {IndexRegistry} from "@eigenlayer-middleware/src/IndexRegistry.sol";
import {StakeRegistry} from "@eigenlayer-middleware/src/StakeRegistry.sol";
import {SocketRegistry} from "@eigenlayer-middleware/src/SocketRegistry.sol";
import {OperatorStateRetriever} from "@eigenlayer-middleware/src/OperatorStateRetriever.sol";
import {
  IBLSApkRegistry,
  IIndexRegistry,
  IStakeRegistry,
  ISocketRegistry,
  ISlashingRegistryCoordinator,
  IRegistryCoordinator
} from "@eigenlayer-middleware/src/RegistryCoordinator.sol";
import {ITransparentUpgradeableProxy} from
  "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract AVSDeployer is Script {
  function run() public {
    _deployCoreContracts();
    _deployAvs();
  }

  function _deployCoreContracts() internal {
    // deploy avs core contracts
    DeployFromScratch deployFromScratch = new DeployFromScratch();
    deployFromScratch.run(
      "../../lib/eigenlayer-middleware/lib/eigenlayer-contracts/script/configs/local/deploy_from_scratch.slashing.anvil.config.json"
    );
  }

  function _deployAvs() internal {
    // core contracts data
    string memory coreContractDeployments =
      vm.readFile("./script/output/local/slashing_output.json");
    IDelegationManager coreDelegationManager = IDelegationManager(
      stdJson.readAddress(coreContractDeployments, ".addresses.delegationManager")
    );
    IAVSDirectory coreAvsDirectory =
      IAVSDirectory(stdJson.readAddress(coreContractDeployments, ".addresses.avsDirectory"));
    IRewardsCoordinator coreRewardsCoordinator = IRewardsCoordinator(
      stdJson.readAddress(coreContractDeployments, ".addresses.rewardsCoordinator")
    );
    IAllocationManager coreAllocationManager = IAllocationManager(
      stdJson.readAddress(coreContractDeployments, ".addresses.allocationManager")
    );
    IPermissionController corePermissionController = IPermissionController(
      stdJson.readAddress(coreContractDeployments, ".addresses.permissionController")
    );
    StrategyBaseTVLLimits coreStrategy =
      StrategyBaseTVLLimits(stdJson.readAddress(coreContractDeployments, ".addresses.strategy"));

    // deploy avs contracts
    address avsCommunityMultisig = msg.sender;
    address avsPauser = msg.sender;
    string memory configData = vm.readFile("./script/config/local/avs.config.json");
    uint32 TASK_RESPONSE_WINDOW_BLOCK =
      uint32(stdJson.readUint(configData, ".avs.squaring.taskManager.taskResponseWindowBlock"));
    address AGGREGATOR_ADDR =
      stdJson.readAddress(configData, ".avs.squaring.taskManager.aggregator");
    address TASK_GENERATOR_ADDR =
      stdJson.readAddress(configData, ".avs.squaring.taskManager.taskGenerator");

    vm.startBroadcast();
    ProxyAdmin avsProxyAdmin = new ProxyAdmin();

    // deploy pauser registry
    address[] memory avsPausers = new address[](2);
    avsPausers[0] = avsCommunityMultisig;
    avsPausers[1] = avsPauser;
    PauserRegistry avsPauserRegistry = new PauserRegistry(avsPausers, avsCommunityMultisig);

    // deploy proxy contracts with empty implementation
    EmptyContract emptyContract = new EmptyContract();
    SquaringServiceManager avsServiceManager = SquaringServiceManager(
      address(new TransparentUpgradeableProxy(address(emptyContract), address(avsProxyAdmin), ""))
    );
    SquaringTaskManager avsTaskManager = SquaringTaskManager(
      address(new TransparentUpgradeableProxy(address(emptyContract), address(avsProxyAdmin), ""))
    );
    RegistryCoordinator avsRegistryCoordinator = RegistryCoordinator(
      address(new TransparentUpgradeableProxy(address(emptyContract), address(avsProxyAdmin), ""))
    );
    BLSApkRegistry avsBlsApkRegistry = BLSApkRegistry(
      address(new TransparentUpgradeableProxy(address(emptyContract), address(avsProxyAdmin), ""))
    );
    IndexRegistry avsIndexRegistry = IndexRegistry(
      address(new TransparentUpgradeableProxy(address(emptyContract), address(avsProxyAdmin), ""))
    );
    StakeRegistry avsStakeRegistry = StakeRegistry(
      address(new TransparentUpgradeableProxy(address(emptyContract), address(avsProxyAdmin), ""))
    );
    SocketRegistry avsSocketRegistry = SocketRegistry(
      address(new TransparentUpgradeableProxy(address(emptyContract), address(avsProxyAdmin), ""))
    );

    // deploy operator state retriever
    OperatorStateRetriever avsOperatorStateRetriever = new OperatorStateRetriever();

    // deploy implementation contracts
    // stake registry - deploy implementation & upgrade
    IStakeRegistry avsStakeRegistryImplementation = new StakeRegistry(
      ISlashingRegistryCoordinator(address(0)),
      coreDelegationManager,
      coreAvsDirectory,
      coreAllocationManager
    );
    avsProxyAdmin.upgrade(
      ITransparentUpgradeableProxy((address(avsStakeRegistry))),
      address(avsStakeRegistryImplementation)
    );

    // bls apk registry - deploy implementation & upgrade
    IBLSApkRegistry avsBlsApkRegistryImplementation = new BLSApkRegistry(avsRegistryCoordinator);
    avsProxyAdmin.upgrade(
      ITransparentUpgradeableProxy(payable(address(avsBlsApkRegistry))),
      address(avsBlsApkRegistryImplementation)
    );

    // index registry - deploy implementation & upgrade
    IIndexRegistry avsIndexRegistryImplementation = new IndexRegistry(avsRegistryCoordinator);
    avsProxyAdmin.upgrade(
      ITransparentUpgradeableProxy(payable(address(avsIndexRegistry))),
      address(avsIndexRegistryImplementation)
    );

    // socket registry - deploy implementation & upgrade
    ISocketRegistry avsSocketRegistryImplementation = new SocketRegistry(avsRegistryCoordinator);
    avsProxyAdmin.upgrade(
      ITransparentUpgradeableProxy(payable(address(avsSocketRegistry))),
      address(avsSocketRegistryImplementation)
    );

    // registry coordinator - deploy implementation & upgrade
    // todo: register operators
    IRegistryCoordinator avsRegistryCoordinatorImplementation = new RegistryCoordinator(
      avsServiceManager,
      avsStakeRegistry,
      avsBlsApkRegistry,
      avsIndexRegistry,
      avsSocketRegistry,
      coreAllocationManager,
      avsPauserRegistry
    );
    avsProxyAdmin.upgrade(
      ITransparentUpgradeableProxy(payable(address(avsRegistryCoordinator))),
      address(avsRegistryCoordinatorImplementation)
    );

    // service manager - deploy implementation & upgrade
    SquaringServiceManager avsServiceManagerImplementation = new SquaringServiceManager(
      coreAvsDirectory,
      coreRewardsCoordinator,
      avsRegistryCoordinator,
      avsStakeRegistry,
      corePermissionController,
      coreAllocationManager,
      avsTaskManager
    );
    avsProxyAdmin.upgrade(
      ITransparentUpgradeableProxy(payable(address(avsServiceManager))),
      address(avsServiceManagerImplementation)
    );

    // task manager - deploy implementation & upgrade
    SquaringTaskManager avsTaskManagerImplementation =
      new SquaringTaskManager(avsRegistryCoordinator, TASK_RESPONSE_WINDOW_BLOCK, avsPauserRegistry);
    avsProxyAdmin.upgradeAndCall(
      ITransparentUpgradeableProxy(payable(address(avsTaskManager))),
      address(avsTaskManagerImplementation),
      abi.encodeWithSelector(
        avsTaskManagerImplementation.initialize.selector,
        avsCommunityMultisig,
        AGGREGATOR_ADDR,
        TASK_GENERATOR_ADDR
      )
    );

    // write avs deployments
    string memory parentObject = "";
    string memory avsDeployedAddresses = "squaringAvs";
    vm.serializeAddress(avsDeployedAddresses, "squaringServiceManager", address(avsServiceManager));
    vm.serializeAddress(
      avsDeployedAddresses,
      "squaringServiceManagerImplementation",
      address(avsServiceManagerImplementation)
    );
    vm.serializeAddress(avsDeployedAddresses, "squaringTaskManager", address(avsTaskManager));
    vm.serializeAddress(
      avsDeployedAddresses,
      "squaringTaskManagerImplementation",
      address(avsTaskManagerImplementation)
    );
    vm.serializeAddress(
      avsDeployedAddresses, "registryCoordinator", address(avsRegistryCoordinator)
    );
    vm.serializeAddress(
      avsDeployedAddresses,
      "registryCoordinatorImplementation",
      address(avsRegistryCoordinatorImplementation)
    );
    string memory avsDeployedAddressesOutput = vm.serializeAddress(
      avsDeployedAddresses, "operatorStateRetriever", address(avsOperatorStateRetriever)
    );

    // serialize all the data
    string memory json =
      vm.serializeString(parentObject, avsDeployedAddresses, avsDeployedAddressesOutput);
    vm.writeJson(json, "./script/output/local/avs_output.json");
  }
}

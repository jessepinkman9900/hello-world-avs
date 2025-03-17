// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ISlashingRegistryCoordinatorTypes} from
  "@eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";

import {Script} from "forge-std/Script.sol";
import {StrategyBase} from "@eigenlayer/contracts/strategies/StrategyBase.sol";
import {ERC20Mock} from "../../src/ERC20Mock.sol";

contract Utils is Script {
  function _mintTokens(
    address strategyAddress,
    address[] memory recipients,
    uint256[] memory amounts
  ) internal {
    ERC20Mock underlyingToken = ERC20Mock(address(StrategyBase(strategyAddress).underlyingToken()));
    for (uint256 i = 0; i < recipients.length; i++) {
      underlyingToken.mint(recipients[i], amounts[i]);
    }
  }

  function convertBoolToString(
    bool input
  ) public pure returns (string memory) {
    return input ? "true" : "false";
  }

  function convertOperatorStatusToString(
    ISlashingRegistryCoordinatorTypes.OperatorStatus operatorStatus
  ) public pure returns (string memory) {
    if (operatorStatus == ISlashingRegistryCoordinatorTypes.OperatorStatus.NEVER_REGISTERED) {
      return "NEVER_REGISTERED";
    } else if (operatorStatus == ISlashingRegistryCoordinatorTypes.OperatorStatus.REGISTERED) {
      return "REGISTERED";
    } else if (operatorStatus == ISlashingRegistryCoordinatorTypes.OperatorStatus.DEREGISTERED) {
      return "DEREGISTERED";
    } else {
      return "UNKNOWN";
    }
  }

  function readInput(
    string memory inputFileName
  ) internal view returns (string memory) {
    string memory inputDir = string.concat(vm.projectRoot(), "/script/input/");
    string memory chainDir = string.concat(vm.toString(block.chainid), "/");
    string memory file = string.concat(inputFileName, ".json");
    return vm.readFile(string.concat(inputDir, chainDir, file));
  }

  function readOutput(
    string memory outputFileName
  ) internal view returns (string memory) {
    string memory inputDir = string.concat(vm.projectRoot(), "/script/output/");
    string memory chainDir = string.concat(vm.toString(block.chainid), "/");
    string memory file = string.concat(outputFileName, ".json");
    return vm.readFile(string.concat(inputDir, chainDir, file));
  }

  function writeOutput(string memory outputJson, string memory outputFileName) internal {
    string memory outputDir = string.concat(vm.projectRoot(), "/script/output/");
    string memory chainDir = string.concat(vm.toString(block.chainid), "/");
    string memory outputFilePath = string.concat(outputDir, chainDir, outputFileName, ".json");
    vm.writeJson(outputJson, outputFilePath);
  }
}

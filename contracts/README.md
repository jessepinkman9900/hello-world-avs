## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
forge build
```

### Static Analysis

```shell
slither .
```

### Test

```shell
forge test
```

### Format

```shell
forge fmt
```

### Gas Snapshots

```shell
forge snapshot
```

### Anvil

```shell
anvil
```

### Deploy

```shell
forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
cast <subcommand>
```

### Help

```shell
forge --help
anvil --help
cast --help
```


### Deploy

```shell
# deploy avs - core + middleware
forge script script/AVSDeployer.s.sol:AVSDeployer --rpc-url $ANVIL_RPC_URL --broadcast -vvvv --interactives 1

# create task
cast send --rpc-url http://localhost:8545 0xa82fF9aFd8f496c3d6ac40E2a0F282E47488CFc9 'createNewTask(uint256,uint32,bytes)' 10 10 00 --private-key 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6

# decode event
cast decode-event --sig "NewTaskCreated(uint32 indexed,(uint256,uint32,bytes,uint32))" <data>

```

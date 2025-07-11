## Deployments

### Sponsor
| Chain | Mainnet                                    | Testnet                                     |
|-------|--------------------------------------------|---------------------------------------------|
| Base  | 0x252683e292d7E36977de92a6BF779d6Bc35176D4 | 0x51b188526c48169e1f12e9a83623f3ee215a740b  |

### Reward
| Chain | Mainnet                                    | Testnet                                     |
|-------|--------------------------------------------|---------------------------------------------|
| Base  | 0x1f735280C83f13c6D40aA2eF213eb507CB4c1eC7 | 0x6b08093d7c1f3c216e830a01b793461764df92b4  |

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
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

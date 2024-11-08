# Tevaera Smart Contracts
Tevaera Contracts on ZKsync

The repo consists of tevaera core contracts

### Project Setup

1. Once you clone the repo, run in terminal
> yarn install

2. Clone https://github.com/matter-labs/local-setup repo separately to run zksync image in Docker. Follow the steps as mentioned in the repo to successfully start a ZKsync instant on your local machine

***Make sure to start the ZKsync local-setup via WSL 2 before starting with the below steps.

### Compiling the Contracts

To compile all the contracts, run in terminal: -
> yarn hardhat compile --network <network_name>

### Deploy contracts on ZKsync

To deploy the separate contracts, run in terminal: -
> yarn hardhat deploy-zksync --script <scriptName> --network <network_name>

Ex: yarn hardhat deploy-zksync --script zksync/citizenidv1_deploy.ts --network zksyncSepolia

### Deploy contracts on other chains

To deploy the separate contracts, run in terminal: -
> yarn hardhat run <scriptName> --network <network_name>

Ex: yarn hardhat run deploy/arbitrum/balancerdragonv1_deploy.ts --network arbitrumSepolia

### Testing contracts

To test the CitizenId contract, run in terminal: -
> yarn hardhat test test/cz.id.test.ts

To test the Karma Points contract, run in terminal: -
> yarn hardhat test test/kp.test.ts

### Flatten the contracts

> npx hardhat flatten ./contracts/<ContractName.sol> >> ./Flatten/<FlattenContract.sol>

### Verifying the contracts

https://v2-docs.zksync.io/api/hardhat/compiling-libraries.html#openzeppelin-utility-libraries

https://v2-docs.zksync.io/dev/guide/contract-verification.html#verifying-contracts-using-the-zksync-block-explorer

### ZkSync Regenisis

Get ETH in wallet via ZKsync Bridge or Faucet -> https://portal.zksync.io/
Delete cache-zk and artifacts-zk
Then, compile and re-deploy the contracts

To know more about testing in ZKsync, visit https://v2-docs.zksync.io/api/hardhat/testing.html
To get more info about using Hardhat with ZKsync, visit https://v2-docs.zksync.io/api/hardhat/
To get tokens for testing on ZKsync, visit https://portal.zksync.io
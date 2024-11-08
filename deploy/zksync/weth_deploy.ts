import { Wallet } from "zksync-ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import * as dotenv from "dotenv";

dotenv.config();

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script for the WETH contract`);

  // Initialize the wallet.
  const wallet = new Wallet(`${process.env.CONTRACT_ADMIN_WALLET_PK}`);

  // Create deployer object and load the artifact of the contract we want to deploy.
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact("WETH");

  console.log("wallet address: ", await wallet.getAddress());

  // constructor arguments
  const constructorArgs = [];

  const wethContract = await deployer.deploy(artifact, constructorArgs);
  console.log("args" + wethContract.interface.encodeDeploy(constructorArgs));

  // Show the contract info.
  const contractAddress = await wethContract.getAddress();
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);

  // verify the weth contract
  console.log("Verifying WETH...");
  await hre.run("verify:verify", {
    address: contractAddress,
    constructorArguments: constructorArgs,
  });
}

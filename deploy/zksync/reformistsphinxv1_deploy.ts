import { Contract, ContractFactory, Provider, Wallet } from "zksync-ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import * as dotenv from "dotenv";

dotenv.config();
const TransparentUpgradeableProxy = require("../../artifacts-zk/contracts/proxy/transparent/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json");

// An example of a deploy script that will deploy and call a simple contract.
export default async function(hre: HardhatRuntimeEnvironment) {
  console.log(
    `Running deploy script for the upgradable ReformistSphinxV1 contract with transparent proxy...`
  );

  const provider = new Provider(process.env.ZKSYNC_PROVIDER_URI);
  await provider.ready;
  if (!provider) throw new Error("Please set ZKSYNC_PROVIDER_URI in .env");

  const proxyAdminContractAddress = process.env.PROXY_ADMIN_CONTRACT_ADDRESS;
  if (!proxyAdminContractAddress)
    throw new Error("Please set proxyAdminContractAddress");

  // Initialize the safeWallet.
  const proxyAdminWallet = new Wallet(
    `${process.env.PROXY_ADMIN_WALLET_PK}`,
    provider
  );
  console.log(
    "proxyAdminWallet address: ",
    await proxyAdminWallet.getAddress()
  );

  const contractAdminWallet = new Wallet(
    `${process.env.CONTRACT_ADMIN_WALLET_PK}`,
    provider
  );
  console.log(
    "contractAdminWallet address: ",
    await contractAdminWallet.getAddress()
  );

  // Initialize deployers
  const contractDeployer = new Deployer(hre, contractAdminWallet);

  // Deploy the reformist sphinx contract
  const reformistSphinxArtifact = await contractDeployer.loadArtifact(
    "ReformistSphinxV1"
  );
  const reformistSphinxConstArgs = [];
  const reformistSphinxContract = await contractDeployer.deploy(
    reformistSphinxArtifact,
    reformistSphinxConstArgs
  );
  console.log(
    "args: " +
      reformistSphinxContract.interface.encodeDeploy(reformistSphinxConstArgs)
  );
  console.log(
    `${reformistSphinxArtifact.contractName} was deployed to ${await reformistSphinxContract.getAddress()}`
  );

  const verifyImpl = await hre.run("verify:verify", {
    address: await reformistSphinxContract.getAddress(),
    constructorArguments: reformistSphinxConstArgs
  });

  console.log("Verification res: ", verifyImpl);

  // Deploy the transparent proxy
  const transparentProxyConstArgs = [
    await reformistSphinxContract.getAddress(),
    proxyAdminContractAddress,
    "0x"
  ];
  const transparentUpgradeableProxyFactory = new ContractFactory(
    TransparentUpgradeableProxy.abi,
    TransparentUpgradeableProxy.bytecode,
    proxyAdminWallet
  );
  const transparentProxyContract = await transparentUpgradeableProxyFactory.deploy(
    await reformistSphinxContract.getAddress(),
    proxyAdminContractAddress,
    "0x"
  );
  await transparentProxyContract.waitForDeployment();
  console.log(
    "transparentUpgradeableProxy deployed at:",
    await transparentProxyContract.getAddress()
  );

  const verifyProxy = await hre.run("verify:verify", {
    address: await transparentProxyContract.getAddress(),
    constructorArguments: transparentProxyConstArgs
  });

  console.log("Verification res: ", verifyProxy);

  console.log(`Initializing reformist sphinx v1 through proxy...`);

  const citizenIdContract = process.env.CITIZEN_ID_CONTRACT_ADDRESS;
  if (!citizenIdContract) throw new Error("Please set citizen id address");
  const reformistSphinxIpfsImageUri =
    process.env.REFORMIST_SPHINX_IPFS_IMAGE_URI;
  if (!reformistSphinxIpfsImageUri)
    throw new Error("Please set reformistSphinxIpfsImageUri");

  const RS_JSON = require("../../artifacts-zk/contracts/guardians/ReformistSphinxV1.sol/ReformistSphinxV1.json");
  const RS_ABI = RS_JSON.abi;

  const rsContract = new Contract(
    await transparentProxyContract.getAddress(),
    RS_ABI,
    contractAdminWallet._signerL2()
  );

  const tx = await rsContract.initialize(
    citizenIdContract,
    reformistSphinxIpfsImageUri
  );
  await tx.wait();
  console.log(tx);
}

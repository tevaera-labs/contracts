import * as dotenv from "dotenv";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Contract, ContractFactory, Provider, Wallet } from "zksync-ethers";
import { ethers } from "ethers";

dotenv.config();
const TransparentUpgradeableProxy = require("../../artifacts-zk/contracts/proxy/transparent/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json");

// An example of a deploy script that will deploy and call a simple contract.
export default async function(hre: HardhatRuntimeEnvironment) {
  console.log(
    `Running deploy script for the upgradable CitizenIV1 contract with transparent proxy...`
  );

  // environment variables
  const provider = new Provider(process.env.ZKSYNC_PROVIDER_URI);
  await provider.ready;
  if (!provider) throw new Error("Please set ZKSYNC_PROVIDER_URI in .env");

  const citizenIdIpfsBaseUri = process.env.CITIZEN_ID_IPFS_BASE_URI;
  if (!citizenIdIpfsBaseUri)
    throw new Error("Please set CITIZEN_ID_IPFS_BASE_URI in .env");

  let citizenIdPrice = process.env.CITIZEN_ID_PRICE;
  if (citizenIdPrice)
    citizenIdPrice = ethers.parseUnits(citizenIdPrice, 18).toString();
  else throw new Error("Please set citizen id price");

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

  // // Initialize deployers
  const proxyDeployer = new Deployer(hre, proxyAdminWallet);
  const contractDeployer = new Deployer(hre, contractAdminWallet);

  // Deploy the proxy admin
  const proxyAdminArtifact = await proxyDeployer.loadArtifact(
    "contracts/proxy/transparent/ProxyAdmin.sol:ProxyAdmin"
  );
  const proxyAdminConstArgs = [];
  const proxyAdminContract = await proxyDeployer.deploy(
    proxyAdminArtifact,
    proxyAdminConstArgs
  );
  console.log(
    "args: " + proxyAdminContract.interface.encodeDeploy(proxyAdminConstArgs)
  );
  console.log(
    `${proxyAdminArtifact.contractName} was deployed to ${await proxyAdminContract.getAddress()}`
  );

  const proxyVerifyRes = await hre.run("verify:verify", {
    address: await proxyAdminContract.getAddress(),
    constructorArguments: proxyAdminConstArgs,
  });

  console.log("Verification res: ", proxyVerifyRes);

  // Deploy the citizen id contract
  const citizenIdArtifact = await contractDeployer.loadArtifact("CitizenIDV1");
  const citizenIdConstArgs = [];
  const citizenIdContract = await contractDeployer.deploy(
    citizenIdArtifact,
    citizenIdConstArgs
  );
  console.log(
    "args: " + citizenIdContract.interface.encodeDeploy(citizenIdConstArgs)
  );
  console.log(
    `${citizenIdArtifact.contractName} was deployed to ${await citizenIdContract.getAddress()}`
  );

  // const res = await hre.run("verify:verify", {
  //   address: await citizenIdContract.getAddress(),
  //   constructorArguments: citizenIdConstArgs,
  // });

  // console.log("Verification res: ", res);

  // Deploy the transparent proxy
  const transparentProxyConstArgs = [
    await citizenIdContract.getAddress(),
    await proxyAdminContract.getAddress(),
    "0x"
  ];
  console.log({ bytecode: TransparentUpgradeableProxy.bytecode });
  const transparentUpgradeableProxyFactory = new ContractFactory(
    TransparentUpgradeableProxy.abi,
    TransparentUpgradeableProxy.bytecode,
    proxyAdminWallet
  );
  const transparentProxyContract = await transparentUpgradeableProxyFactory.deploy(
    await citizenIdContract.getAddress(),
    await proxyAdminContract.getAddress(),
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

  // Initializing citizen id contract through proxy
  const CZ_JSON = require("../../artifacts-zk/contracts/citizenid/CitizenIDV1.sol/CitizenIDV1.json");
  const CZ_ABI = CZ_JSON.abi;

  const czContract = new Contract(
    await transparentProxyContract.getAddress(),
    CZ_ABI,
    contractAdminWallet._signerL2()
  );

  const initializeCitizenIdTx = await czContract.initialize(
    citizenIdIpfsBaseUri,
    citizenIdPrice
  );
  await initializeCitizenIdTx.wait();
  console.log("CitizenIDV1 initialization response: ", initializeCitizenIdTx);
}

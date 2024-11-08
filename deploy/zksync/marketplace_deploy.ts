import { Contract, ContractFactory, Provider, Wallet } from "zksync-ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import * as dotenv from "dotenv";

dotenv.config();
const TransparentUpgradeableProxy = require("../../artifacts-zk/contracts/proxy/transparent/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json");

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(
    `Running deploy script for the upgradable MarketplaceV1 contract with transparent proxy...`
  );

  // environment variables
  const provider = new Provider(process.env.ZKSYNC_PROVIDER_URI);
  if (!provider) throw new Error("Please set zksync provider url");
  const proxyAdminContractAddress = process.env.PROXY_ADMIN_CONTRACT_ADDRESS;
  if (!proxyAdminContractAddress)
    throw new Error("Please set proxy admin contract address.");
  const marketplaceContractIpfsUrl = process.env.MARKETPLACE_CONTRACT_IPFS_URL;
  if (!marketplaceContractIpfsUrl)
    throw new Error("Please set marketplace contract address.");
  const safeAddress = process.env.SAFE_ADDRESS;
  if (!safeAddress) throw new Error("Please set safe address");
  const wethAddress = process.env.WETH_ADDRESS;
  if (!wethAddress) throw new Error("Please set wETH address");

  // Initialize the safeWallet.
  const proxyAdminWallet = new Wallet(
    `${process.env.PROXY_ADMIN_WALLET_PK}`,
    provider
  );
  console.log("proxyAdminWallet address: ", await proxyAdminWallet.getAddress());

  const contractAdminWallet = new Wallet(
    `${process.env.CONTRACT_ADMIN_WALLET_PK}`,
    provider
  );
  console.log("contractAdminWallet address: ", await contractAdminWallet.getAddress());

  // Initialize deployers
  const proxyDeployer = new Deployer(hre, proxyAdminWallet);
  const contractDeployer = new Deployer(hre, contractAdminWallet);

  // Deploy the magical marketplaceV1 contract
  console.log("Deploying MarketplaceV1...");
  const marketplaceArtifact = await contractDeployer.loadArtifact(
    "MarketplaceV1"
  );
  const marketplaceConstArgs = [wethAddress];
  const marketplaceContract = await contractDeployer.deploy(
    marketplaceArtifact,
    marketplaceConstArgs
  );
  console.log(
    "MarketplaceV1 Constructor Args: " +
      marketplaceContract.interface.encodeDeploy(marketplaceConstArgs)
  );
  console.log(
    `${marketplaceArtifact.contractName} was deployed to ${await marketplaceContract.getAddress()}`
  );

  // verify the magical marketplaceV1 contract
  console.log("Verifying MarketplaceV1...");
  await hre.run("verify:verify", {
    address: await marketplaceContract.getAddress(),
    constructorArguments: marketplaceConstArgs,
  });

  // Deploy the magical marketplace transparent proxy
  console.log("Deploying MarketplaceTransparentUpgradeableProxy...");
  const transparentProxyConstArgs = [
    await marketplaceContract.getAddress(),
    proxyAdminContractAddress,
    "0x",
  ];
  const transparentUpgradeableProxyFactory = new ContractFactory(
    TransparentUpgradeableProxy.abi,
    TransparentUpgradeableProxy.bytecode,
    proxyAdminWallet
  );
  const transparentProxyContract =
    await transparentUpgradeableProxyFactory.deploy(
      await marketplaceContract.getAddress(),
      proxyAdminContractAddress,
      "0x",
    );
  await transparentProxyContract.waitForDeployment();
  console.log(
    "transparentUpgradeableProxy deployed at:",
    await transparentProxyContract.getAddress()
  );

  const verifyProxy = await hre.run("verify:verify", {
    address: await transparentProxyContract.getAddress(),
    constructorArguments: transparentProxyConstArgs,
  });

  console.log("Verification res: ", verifyProxy);

  console.log(
    `Initializing MarketplaceV1 through MarketplaceTransparentUpgradeableProxy...`
  );

  // Initializing magical marketplace contract through proxy
  const MP_JSON = require("../../artifacts-zk/contracts/marketplace/MarketplaceV1.sol/MarketplaceV1.json");
  const MP_ABI = MP_JSON.abi;

  const mpContract = new Contract(
    await transparentProxyContract.getAddress(),
    MP_ABI,
    contractAdminWallet._signerL2()
  );

  const initializeMpTx = await mpContract.initialize(
    marketplaceContractIpfsUrl,
    [],
    safeAddress,
    process.env.CITIZEN_ID_CONTRACT_ADDRESS
  );
  await initializeMpTx.wait();
  console.log("MarketplaceV1 initialization response: ", initializeMpTx);
}

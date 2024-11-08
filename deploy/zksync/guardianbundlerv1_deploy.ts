import { ethers } from "ethers";
import { Contract, ContractFactory, Provider, Wallet } from "zksync-ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import * as dotenv from "dotenv";

dotenv.config();
const TransparentUpgradeableProxy = require("../../artifacts-zk/contracts/proxy/transparent/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json");

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(
    `Running deploy script for the upgradable GuardianBundlerV1 contract with transparent proxy...`
  );

  // environment variables
  const provider = new Provider(process.env.ZKSYNC_PROVIDER_URI);
  if (!provider) throw new Error("Please set zksync provider url");
  const proxyAdminContractAddress = process.env.PROXY_ADMIN_CONTRACT_ADDRESS;
  if (!proxyAdminContractAddress)
    throw new Error("Please set proxyAdminContractAddress");
  const nomadicYetiContractAddress =
    process.env.ZKSYNC_NOMADIC_YETI_CONTRACT_ADDRESS;
  if (!nomadicYetiContractAddress)
    throw new Error("Please set nomadicYetiContractAddress");
  const balancerDragonContractAddress =
    process.env.ZKSYNC_BALANCER_DRAGON_CONTRACT_ADDRESS;
  if (!balancerDragonContractAddress)
    throw new Error("Please set balancerDragonContractAddress");
  const influentialWerewolfContractAddress =
    process.env.ZKSYNC_INFLUENTIAL_WEREWOLF_CONTRACT_ADDRESS;
  if (!influentialWerewolfContractAddress)
    throw new Error("Please set influentialWerewolfContractAddress");
  const innovativeUnicornContractAddress =
    process.env.ZKSYNC_INNOVATIVE_UNICORN_CONTRACT_ADDRESS;
  if (!innovativeUnicornContractAddress)
    throw new Error("Please set innovativeUnicornContractAddress");
  const simplifierKrakenContractAddress =
    process.env.ZKSYNC_SIMPLIFIER_KRAKEN_CONTRACT_ADDRESS;
  if (!simplifierKrakenContractAddress)
    throw new Error("Please set simplifierKrakenContractAddress");
  const safeAddress = process.env.SAFE_ADDRESS;
  if (!safeAddress) throw new Error("Please set safe address");
  const bundleGuardianPrice = ethers.parseEther(
    process.env.BUNDLE_GUARDIAN_PRICE as string
  );
  if (!bundleGuardianPrice) throw new Error("Please set bundleGuardianPrice");

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

  // Deploy the gunadian bundler contract
  const guardianBundlerArtifact = await contractDeployer.loadArtifact(
    "contracts/guardians/GuardianBundlerV1.sol:GuardianBundlerV1"
  );
  const guardianBundlerConstArgs = [];
  const guardianBundlerContract = await contractDeployer.deploy(
    guardianBundlerArtifact,
    guardianBundlerConstArgs
  );
  console.log(
    "args: " +
      guardianBundlerContract.interface.encodeDeploy(guardianBundlerConstArgs)
  );
  console.log(
    `${guardianBundlerArtifact.contractName} was deployed to ${await guardianBundlerContract.getAddress()}`
  );

  const verifyImpl = await hre.run("verify:verify", {
    address: await guardianBundlerContract.getAddress(),
    constructorArguments: guardianBundlerConstArgs
  });

  console.log("Verification res: ", verifyImpl);

  // Deploy the transparent proxy
  const transparentProxyConstArgs = [
    await guardianBundlerContract.getAddress(),
    proxyAdminContractAddress,
    "0x"
  ];
  const transparentUpgradeableProxyFactory = new ContractFactory(
    TransparentUpgradeableProxy.abi,
    TransparentUpgradeableProxy.bytecode,
    proxyAdminWallet
  );
  const transparentProxyContract =
    await transparentUpgradeableProxyFactory.deploy(
      await guardianBundlerContract.getAddress(),
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
    constructorArguments: transparentProxyConstArgs,
  });

  console.log("Verification res: ", verifyProxy);

  // Initializing GuardianBundlerV1 contract through proxy
  const NY_JSON = require("../../artifacts-zk/contracts/guardians/GuardianBundlerV1.sol/GuardianBundlerV1.json");
  const NY_ABI = NY_JSON.abi;

  const nyContract = new Contract(
    await transparentProxyContract.getAddress(),
    NY_ABI,
    contractAdminWallet._signerL2()
  );

  const initializeMpTx = await nyContract.initialize(
    balancerDragonContractAddress,
    influentialWerewolfContractAddress,
    innovativeUnicornContractAddress,
    nomadicYetiContractAddress,
    simplifierKrakenContractAddress,
    safeAddress,
    bundleGuardianPrice
  );
  await initializeMpTx.wait();
  console.log("GuardianBundlerV1 initialization response: ", initializeMpTx);
}

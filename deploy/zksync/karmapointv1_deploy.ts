import { Contract, ContractFactory, Provider, Wallet } from "zksync-ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import * as dotenv from "dotenv";
import { ethers } from "ethers";

dotenv.config();
const TransparentUpgradeableProxy = require("../../artifacts-zk/contracts/proxy/transparent/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json");

// An example of a deploy script that will deploy and call a simple contract.
export default async function(hre: HardhatRuntimeEnvironment) {
  console.log(
    `Running deploy script for the upgradable KarmaPointV1 contract with transparent proxy...`
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

  // Deploy the karma point contract
  const karmaPointArtifact = await contractDeployer.loadArtifact(
    "KarmaPointV1"
  );
  const karmaPointConstArgs = [];
  const karmaPointContract = await contractDeployer.deploy(
    karmaPointArtifact,
    karmaPointConstArgs
  );
  console.log(
    "args: " + karmaPointContract.interface.encodeDeploy(karmaPointConstArgs)
  );
  console.log(
    `${karmaPointArtifact.contractName} was deployed to ${await karmaPointContract.getAddress()}`
  );

  const verifyImplProxy = await hre.run("verify:verify", {
    address: await karmaPointContract.getAddress(),
    constructorArguments: karmaPointConstArgs
  });

  console.log("Verification res: ", verifyImplProxy);

  // Deploy the transparent proxy
  const transparentProxyConstArgs = [
    await karmaPointContract.getAddress(),
    proxyAdminContractAddress,
    "0x"
  ];
  console.log({
    transparentProxyConstArgs,
    abi: TransparentUpgradeableProxy.abi,
    bytescode: TransparentUpgradeableProxy.bytecode,
    proxyAdminWallet
  });
  const transparentUpgradeableProxyFactory = new ContractFactory(
    TransparentUpgradeableProxy.abi,
    TransparentUpgradeableProxy.bytecode,
    proxyAdminWallet
  );
  const transparentProxyContract = await transparentUpgradeableProxyFactory.deploy(
    await karmaPointContract.getAddress(),
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

  console.log(`Initializing karma point v1 through proxy...`);

  const citizenIdContract = process.env.CITIZEN_ID_CONTRACT_ADDRESS;
  if (!citizenIdContract) throw new Error("Please set citizen id address");
  const safeAddress = process.env.SAFE_ADDRESS;
  if (!safeAddress) throw new Error("Please set safeAddress");
  let kpPrice = process.env.KP_PRICE;
  if (kpPrice) kpPrice = ethers.parseUnits(kpPrice, 18).toString();
  else throw new Error("please set kp price");
  const kpTotalSupplyCap = process.env.KP_TOTAL_SUPPLY_CAP;
  if (!kpTotalSupplyCap) throw new Error("Please set kpTotalSupplyCap");
  const kpBuyCap = process.env.KP_BUY_CAP;
  if (!kpBuyCap) throw new Error("Please set kpBuyCap");

  const KP_JSON = require("../../artifacts-zk/contracts/karmapoint/KarmaPointV1.sol/KarmaPointV1.json");
  const KP_ABI = KP_JSON.abi;

  const kpContract = new Contract(
    await transparentProxyContract.getAddress(),
    KP_ABI,
    contractAdminWallet._signerL2()
  );

  const tx = await kpContract.initialize(
    citizenIdContract,
    safeAddress,
    kpPrice,
    kpTotalSupplyCap,
    kpBuyCap
  );
  await tx.wait();
  console.log(tx);
}

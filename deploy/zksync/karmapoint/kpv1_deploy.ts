import { Contract, ContractFactory, Provider, Wallet } from "zksync-ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import * as dotenv from "dotenv";

dotenv.config();
const TransparentUpgradeableProxy = require("../../../artifacts-zk/contracts/proxy/transparent/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json");

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(
    `Running deploy script for the upgradable KPV1 contract with transparent proxy...`
  );

  // environment variables
  const provider = new Provider(process.env.ZKSYNC_PROVIDER_URI);
  if (!provider) throw new Error("Please set zksync provider url");
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
  const kpArtifact = await contractDeployer.loadArtifact(
    "contracts/karmapoint/KPV1.sol:KarmaPointV1"
  );
  const kpConstArgs = [];
  const kpContract = await contractDeployer.deploy(kpArtifact, kpConstArgs);
  console.log("args: " + kpContract.interface.encodeDeploy(kpConstArgs));
  console.log(
    `${
      kpArtifact.contractName
    } was deployed to ${await kpContract.getAddress()}`
  );

  const verifyImpl = await hre.run("verify:verify", {
    address: await kpContract.getAddress(),
    constructorArgument: kpConstArgs,
  });

  console.log("Verification res: ", verifyImpl);

  // Deploy the transparent proxy
  const transparentProxyConstArgs = [
    await kpContract.getAddress(),
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
      await kpContract.getAddress(),
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

  // Initializing KPV1 contract through proxy
  const KP_JSON = require("../../../artifacts-zk/contracts/karmapoint/KPV1.sol/KarmaPointV1.json");
  const KP_ABI = KP_JSON.abi;

  const contract = new Contract(
    await transparentProxyContract.getAddress(),
    KP_ABI,
    contractAdminWallet._signerL2()
  );

  const initializeTx = await contract.initialize();
  await initializeTx.wait();

  console.log("KPV1 initialization response: ", initializeTx);
}

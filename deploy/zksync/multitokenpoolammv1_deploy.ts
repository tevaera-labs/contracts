import { Contract, ContractFactory, Provider, Wallet } from "zksync-ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import * as dotenv from "dotenv";

dotenv.config();
const TransparentUpgradeableProxy = require("../../artifacts-zk/contracts/proxy/transparent/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json");

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(
    `Running deploy script for the upgradable MultiTokenPoolAmmV1 contract with transparent proxy...`
  );

  // // environment variables
  const provider = new Provider(process.env.ZKSYNC_PROVIDER_URI);
  if (!provider) throw new Error("Please set zksync provider url");
  const proxyAdminContractAddress = process.env.PROXY_ADMIN_CONTRACT_ADDRESS;
  if (!proxyAdminContractAddress)
    throw new Error("Please set proxyAdminContractAddress");
  const tevaTokenContract = process.env.TEVA_TOKEN_CONTRCAT;
  if (!tevaTokenContract) throw new Error("Please set tevaTokenContract");
  const kpTokenContract = process.env.KP_TOKEN_CONTRACT;
  if (!kpTokenContract) throw new Error("Please set kpTokenContract");
  const trustedCaller = process.env.TRUSTED_CALLER;
  if (!trustedCaller) throw new Error("Please set trustedCaller");

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

  // Deploy the simplifier kraken contract
  const MultiTokenPoolAmmV1Artifact = await contractDeployer.loadArtifact(
    "contracts/dex/MultiTokenPoolAmmV1.sol:MultiTokenPoolAmmV1"
  );
  const MultiTokenPoolAmmV1ConstArgs = [];
  const MultiTokenPoolAmmV1Contract = await contractDeployer.deploy(
    MultiTokenPoolAmmV1Artifact,
    MultiTokenPoolAmmV1ConstArgs
  );
  console.log(
    "args: " +
    MultiTokenPoolAmmV1Contract.interface.encodeDeploy(
      MultiTokenPoolAmmV1ConstArgs
    )
  );
  console.log(
    `MultiTokenPoolAmmV1 was deployed to ${await MultiTokenPoolAmmV1Contract.getAddress()}`
  );

  const verifyMultiTokenPoolAmmV1 = await hre.run("verify:verify", {
    address: await MultiTokenPoolAmmV1Contract.getAddress(),
    constructorArguments: MultiTokenPoolAmmV1ConstArgs,
  });

  console.log("Verification res: ", verifyMultiTokenPoolAmmV1);

  // Deploy the transparent proxy
  const transparentProxyConstArgs = [
    await MultiTokenPoolAmmV1Contract.getAddress(),
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
      await MultiTokenPoolAmmV1Contract.getAddress(),
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

  // Initializing MultiTokenPoolAmmV1 contract through proxy
  const NY_JSON = require("../../artifacts-zk/contracts/dex/MultiTokenPoolAmmV1.sol/MultiTokenPoolAmmV1.json");
  const NY_ABI = NY_JSON.abi;

  const nyContract = new Contract(
    await transparentProxyContract.getAddress(),
    NY_ABI,
    contractAdminWallet._signerL2()
  );

  const initializeMultiTokenPoolAmmV1Tx = await nyContract.initialize(tevaTokenContract, trustedCaller, kpTokenContract);
  await initializeMultiTokenPoolAmmV1Tx.wait();
  console.log(
    "MultiTokenPoolAmmV1 initialization response: ",
    initializeMultiTokenPoolAmmV1Tx
  );
}

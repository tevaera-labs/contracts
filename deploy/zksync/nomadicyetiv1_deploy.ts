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
    `Running deploy script for the upgradable NomadicYetiV1 contract with transparent proxy...`
  );

  // environment variables
  const provider = new Provider(process.env.ZKSYNC_PROVIDER_URI);
  if (!provider) throw new Error("Please set zksync provider url");
  const proxyAdminContractAddress = process.env.PROXY_ADMIN_CONTRACT_ADDRESS;
  if (!proxyAdminContractAddress)
    throw new Error("Please set proxyAdminContractAddress");
  const layerzeroZkSyncEndpoint = process.env.LAYERZERO_ZKSYNC_ENDPOINT;
  if (!layerzeroZkSyncEndpoint)
    throw new Error("Please set zksync layer zero endpoint");
  const safeAddress = process.env.SAFE_ADDRESS;
  if (!safeAddress) throw new Error("Please set safe address");
  const crosschainTransferFee = ethers.parseEther(
    process.env.CROSSCHAIN_TRANSFER_FEE as string
  );
  if (!crosschainTransferFee) throw new Error("Please set crosschain fee");
  const minGasToTransferAndStore = ethers.parseEther(
    process.env.MIN_GAS_TO_TRANSFER_AND_STORE as string
  );
  if (!minGasToTransferAndStore)
    throw new Error("Please set minGasToTransferAndStore");
  const singleGuardianPrice = ethers.parseEther(
    process.env.SINGLE_GUARDIAN_PRICE as string
  );
  if (!singleGuardianPrice) throw new Error("Please set singleGuardianPrice");
  const nomadicYetiIpfsContractUri = process.env.NOMADIC_YETI_IPFS_CONTRACT_URI;
  if (!nomadicYetiIpfsContractUri)
    throw new Error("Please set nomadicYetiIpfsContractUri");
  const nomadicYetiIpfsBaseUri = process.env.NOMADIC_YETI_IPFS_BASE_URI;
  if (!nomadicYetiIpfsBaseUri)
    throw new Error("Please set nomadicYetiIpfsBaseUri");

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

  // Deploy the nomadic yeti contract
  const nomadicYetiArtifact = await contractDeployer.loadArtifact(
    "contracts/guardians/NomadicYetiV1.sol:NomadicYetiV1"
  );
  const nomadicYetiConstArgs = [];
  const nomadicYetiContract = await contractDeployer.deploy(
    nomadicYetiArtifact,
    nomadicYetiConstArgs
  );
  console.log(
    "args: " + nomadicYetiContract.interface.encodeDeploy(nomadicYetiConstArgs)
  );
  console.log(
    `${nomadicYetiArtifact.contractName} was deployed to ${await nomadicYetiContract.getAddress()}`
  );

  const verifyImpl = await hre.run("verify:verify", {
    address: await nomadicYetiContract.getAddress(),
    constructorArguments: nomadicYetiConstArgs
  });

  console.log("Verification res: ", verifyImpl);

  // Deploy the transparent proxy
  const transparentProxyConstArgs = [
    await nomadicYetiContract.getAddress(),
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
      await nomadicYetiContract.getAddress(),
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

  // Initializing NomadicYetiV1 contract through proxy
  const NY_JSON = require("../../artifacts-zk/contracts/guardians/NomadicYetiV1.sol/NomadicYetiV1.json");
  const NY_ABI = NY_JSON.abi;

  const nyContract = new Contract(
    await transparentProxyContract.getAddress(),
    NY_ABI,
    contractAdminWallet._signerL2()
  );

  const initializeMpTx = await nyContract.initialize(
    layerzeroZkSyncEndpoint,
    safeAddress,
    crosschainTransferFee,
    minGasToTransferAndStore,
    singleGuardianPrice,
    nomadicYetiIpfsContractUri,
    nomadicYetiIpfsBaseUri
  );
  await initializeMpTx.wait();
  console.log("NomadicYetiV1 initialization response: ", initializeMpTx);
}

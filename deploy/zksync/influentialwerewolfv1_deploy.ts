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
    `Running deploy script for the upgradable InfluentialWerewolfV1 contract with transparent proxy...`
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
  const influentialWerewolfIpfsContractUri =
    process.env.INFLUENTIAL_WEREWOLF_IPFS_CONTRACT_URI;
  if (!influentialWerewolfIpfsContractUri)
    throw new Error("Please set influentialWerewolfIpfsContractUri");
  const influentialWerewolfIpfsBaseUri =
    process.env.INFLUENTIAL_WEREWOLF_IPFS_BASE_URI;
  if (!influentialWerewolfIpfsBaseUri)
    throw new Error("Please set influentialWerewolfIpfsBaseUri");

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

  // Deploy the influential werewolf contract
  const influentialWerewolfArtifact = await contractDeployer.loadArtifact(
    "contracts/guardians/InfluentialWerewolfV1.sol:InfluentialWerewolfV1"
  );
  const influentialWerewolfConstArgs = [];
  const influentialWerewolfContract = await contractDeployer.deploy(
    influentialWerewolfArtifact,
    influentialWerewolfConstArgs
  );
  console.log(
    "args: " +
      influentialWerewolfContract.interface.encodeDeploy(
        influentialWerewolfConstArgs
      )
  );
  console.log(
    `${influentialWerewolfArtifact.contractName} was deployed to ${await influentialWerewolfContract.getAddress()}`
  );

  const verifyImpl = await hre.run("verify:verify", {
    address: await influentialWerewolfContract.getAddress(),
    constructorArguments: influentialWerewolfConstArgs
  });

  console.log("Verification res: ", verifyImpl);

  // Deploy the transparent proxy
  const transparentProxyConstArgs = [
    await influentialWerewolfContract.getAddress(),
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
      await influentialWerewolfContract.getAddress(),
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


  // Initializing InfluentialWerewolfV1 contract through proxy
  const NY_JSON = require("../../artifacts-zk/contracts/guardians/InfluentialWerewolfV1.sol/InfluentialWerewolfV1.json");
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
    influentialWerewolfIpfsContractUri,
    influentialWerewolfIpfsBaseUri
  );
  await initializeMpTx.wait();
  console.log(
    "InfluentialWerewolfV1 initialization response: ",
    initializeMpTx
  );
}

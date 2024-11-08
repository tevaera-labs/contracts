import { Contract, ContractFactory, Provider, Wallet } from "zksync-ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import * as dotenv from "dotenv";

dotenv.config();
const TransparentUpgradeableProxy = require("../../artifacts-zk/contracts/proxy/transparent/TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json");

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(
    `Running deploy script for the upgradable MagicalPhoenixV1 contract with transparent proxy...`
  );

  // environment variables
  const provider = new Provider(process.env.ZKSYNC_PROVIDER_URI);
  if (!provider) throw new Error("Please set zksync provider url");
  const proxyAdminContractAddress = process.env.PROXY_ADMIN_CONTRACT_ADDRESS;
  if (!proxyAdminContractAddress)
    throw new Error("Please set proxy admin contract address.");
  const citizenIdContract = process.env.CITIZEN_ID_CONTRACT_ADDRESS;
  if (!citizenIdContract)
    throw new Error("Please set citizen id contract address.");
  const magicalPhoenixIpfsBaseUri = process.env.MAGICAL_PHOENIX_IPFS_BASE_URI;
  if (!magicalPhoenixIpfsBaseUri)
    throw new Error("Please set magical phoenix ipfs base url.");
  const magicalPhoenixIpfsContractUri =
    process.env.MAGICAL_PHOENIX_IPFS_CONTRACT_URI;
  if (!magicalPhoenixIpfsContractUri)
    throw new Error("Please set magical phoenix ipfs contract url.");
  const safeAddress = process.env.SAFE_ADDRESS;
  if (!safeAddress) throw new Error("Please set safe address");

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

  // Deploy the magical phoenixV1 contract
  console.log("Deploying MagicalPhoenixV1...");
  const magicalPhoenixArtifact = await contractDeployer.loadArtifact(
    "MagicalPhoenixV1"
  );
  const magicalPhoenixConstArgs = [];
  const magicalPhoenixContract = await contractDeployer.deploy(
    magicalPhoenixArtifact,
    magicalPhoenixConstArgs
  );
  console.log(
    "MagicalPhoenixV1 Constructor Args: " +
      magicalPhoenixContract.interface.encodeDeploy(magicalPhoenixConstArgs)
  );
  console.log(
    `${magicalPhoenixArtifact.contractName} was deployed to ${await magicalPhoenixContract.getAddress()}`
  );

  // verify the magical phoenixV1 contract
  console.log("Verifying MagicalPhoenixV1...");
  await hre.run("verify:verify", {
    address: await magicalPhoenixContract.getAddress(),
    constructorArguments: magicalPhoenixConstArgs,
  });

  // Deploy the magical phoenix transparent proxy
  console.log("Deploying MagicalPhoenixTransparentUpgradeableProxy...");
  const transparentProxyConstArgs = [
    await magicalPhoenixContract.getAddress(),
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
      await magicalPhoenixContract.getAddress(),
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
    `Initializing MagicalPhoenixV1 through MagicalPhoenixTransparentUpgradeableProxy...`
  );

  // Initializing magical phoenix contract through proxy
  const MP_JSON = require("../../artifacts-zk/contracts/guardians/MagicalPhoenixV1.sol/MagicalPhoenixV1.json");
  const MP_ABI = MP_JSON.abi;

  const mpContract = new Contract(
    await transparentProxyContract.getAddress(),
    MP_ABI,
    contractAdminWallet._signerL2()
  );

  console.log({citizenIdContract,
    magicalPhoenixIpfsContractUri,
    magicalPhoenixIpfsBaseUri,
    safeAddress});

  const initializeMpTx = await mpContract.initialize(
    citizenIdContract,
    magicalPhoenixIpfsContractUri,
    magicalPhoenixIpfsBaseUri,
    safeAddress
  );
  await initializeMpTx.wait();
  console.log("MagicalPhoenixV1 initialization response: ", initializeMpTx);
}

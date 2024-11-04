import "@matterlabs/hardhat-zksync-deploy";
import "@matterlabs/hardhat-zksync-solc";
import "@matterlabs/hardhat-zksync-verify";
import "@matterlabs/hardhat-zksync-upgradable";
import "@nomicfoundation/hardhat-toolbox";

const config = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  zksolc: {
    version: "1.4.1",
    compilerSource: "binary",
    settings: {},
  },
  defaultNetwork: "zkSyncSepolia",

  networks: {
    hardhat: {
      zksync: true,
    },
    zkSyncLocal: {
      url: "http://localhost:8011",
      ethNetwork: "http://localhost:8545",
      zksync: true,
    },
    zkSyncGoerli: {
      url: "https://testnet.era.zksync.dev",
      ethNetwork: "goerli",
      zksync: true,
      verifyURL:
        "https://zksync2-testnet-explorer.zksync.dev/contract_verification",
    },
    zkSyncSepolia: {
      url: "https://sepolia.era.zksync.dev",
      ethNetwork: "sepolia",
      zksync: true,
      verifyURL:
        "https://explorer.sepolia.era.zksync.dev/contract_verification",
    },
    zkSyncMainnet: {
      url: "https://mainnet.era.zksync.io",
      ethNetwork: "mainnet",
      zksync: true,
      verifyURL:
        "https://zksync2-mainnet-explorer.zksync.io/contract_verification",
    },
    arbitrumGoerli: {
      url: "https://goerli-rollup.arbitrum.io/rpc",
      zksync: false,
    },
    arbitrumSepolia: {
      url: "https://sepolia-rollup.arbitrum.io/rpc",
      zksync: false,
    },
    arbitrumOne: {
      url: "https://arb1.arbitrum.io/rpc",
      zksync: false,
    },
    lineaGoerli: {
      url: "https://rpc.goerli.linea.build",
      zksync: false,
    },
    baseGoerli: {
      url: "https://goerli.base.org",
      zksync: false,
    },
    baseSepolia: {
      url: "https://sepolia.base.org",
      zksync: false,
    },
    scrollSepolia: {
      url: "https://sepolia-rpc.scroll.io",
      zksync: false,
    },
  },
  etherscan: {
    apiKey: {
      arbitrumGoerli: "KY7VQ8AYNP5C29DJUYGDIPBFC5VD13JS3D",
      linea_testnet: "GX5C89P3SWF2CK9EXQBAD2KW9WGBRQNX53",
    },
    customChains: [
      {
        network: "linea_testnet",
        chainId: 59140,
        urls: {
          apiURL: "https://api-testnet.lineascan.build/api",
          browserURL: "https://goerli.lineascan.build/address",
        },
      },
    ],
  },
};

export default config;

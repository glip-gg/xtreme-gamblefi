require("@nomicfoundation/hardhat-toolbox");

const defaultNetwork = "localhost";

module.exports = {
  solidity: {
    version: '0.8.24',
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000,
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  defaultNetwork,
  networks: {
    localhost: {
        url: "http://localhost:8545",
        accounts: ["0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"]
      },
  
  },
  // abiExporter: {
  //   path: './src/data/abi',
  //   clear: true,
  //   runOnCompile: true,
  //   flat: true,
  //   only: ['Xtremeverse'],
  //   spacing: 2
  // },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: "87RP6PBVRSBTRE2U8IB7JZ4765M31BRJEX"
  },
  sourcify: {
    enabled: true
  }
};


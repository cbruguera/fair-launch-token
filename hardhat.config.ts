import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";

require('dotenv').config();
const mnemonic = process.env.WALLET_KEY as string;

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    // Base mainnet
    'base-mainnet': {
      url: 'https://mainnet.base.org',
      accounts: {
        mnemonic: mnemonic,
      },
      gasPrice: 1000000000,
    },
    // Base testnet
    'base-sepolia': {
      url: 'https://sepolia.base.org',
      accounts: {
        mnemonic: mnemonic,
      },
      gasPrice: 1000000000,
    },
    // local Base environment
    'base-local': {
      url: 'http://localhost:8545',
      accounts: {
        mnemonic: mnemonic,
      },
      gasPrice: 1000000000,
    },
  },
  defaultNetwork: 'hardhat',
};

export default config;

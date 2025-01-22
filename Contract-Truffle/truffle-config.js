const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config();

module.exports = {
  networks: {
    testmanta: {
      provider: () =>
        new HDWalletProvider(
          [process.env.PRIVATE_KEY], 
          "https://pacific-rpc.sepolia-testnet.manta.network/http" 
        ),
      network_id: 3441006, 
      gas: 5500000, 
      gasPrice: 20000000000, 
    },
  },
  compilers: {
    solc: {
      version: "0.8.0", 
    },
  },
};

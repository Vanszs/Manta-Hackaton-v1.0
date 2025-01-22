const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config();

try {
  const provider = new HDWalletProvider(
    [process.env.PRIVATE_KEY], // Private key tanpa 0x
    "https://pacific-rpc.sepolia-testnet.manta.network/http"
  );

  console.log("Wallet Address:", provider.getAddress(0)); // Alamat wallet pertama
} catch (error) {
  console.error("Provider Error:", error.message);
}

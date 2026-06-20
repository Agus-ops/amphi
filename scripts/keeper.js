// keeper.js — Update harga ETH, BTC, XAU ke AmphiOracle setiap 15 menit
import { ethers } from "ethers";
import fs from "fs";
import dotenv from "dotenv";
dotenv.config({ path: "/opt/amphi/.env" });

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const RPC_URL = process.env.GIWA_RPC_URL;
const ORACLE_ADDR = "0xFF5A696a85734205360A04D0005Eb666dE7a9B08";

const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

const oracleAbi = [
  "function updatePrices(uint256 _ethUsd, uint256 _btcUsd, uint256 _xauUsd) external",
  "function lastUpdate() external view returns (uint256)",
  "function ethUsd() external view returns (uint256)",
  "function btcUsd() external view returns (uint256)",
  "function xauUsd() external view returns (uint256)",
  "function getGoldPricePerGram() external view returns (uint256)"
];
const oracle = new ethers.Contract(ORACLE_ADDR, oracleAbi, wallet);

async function getCryptoPrices() {
  try {
    const res = await fetch("https://api.coingecko.com/api/v3/simple/price?ids=ethereum,bitcoin&vs_currencies=usd");
    const data = await res.json();
    const ethUsd = Math.round(data.ethereum.usd * 1e8); // 8 desimal
    const btcUsd = Math.round(data.bitcoin.usd * 1e8);
    return { ethUsd, btcUsd };
  } catch (e) {
    console.error("CoinGecko fetch failed:", e.message);
    return null;
  }
}

async function getGoldPrice() {
  try {
    const res = await fetch("https://api.gold-api.com/price/XAU/USD");
    const data = await res.json();
    const xauUsd = Math.round(data.price * 1e8); // 8 desimal
    return xauUsd;
  } catch (e) {
    console.error("Gold API fetch failed:", e.message);
    return null;
  }
}

async function updatePrices() {
  console.log(`[${new Date().toISOString()}] Fetching prices...`);
  
  const crypto = await getCryptoPrices();
  if (!crypto) return console.log("  Crypto fetch failed, skip");
  
  const xauUsd = await getGoldPrice();
  if (!xauUsd) return console.log("  Gold fetch failed, skip");
  
  console.log(`  ETH: $${crypto.ethUsd / 1e8}, BTC: $${crypto.btcUsd / 1e8}, XAU: $${xauUsd / 1e8}`);
  
  try {
    const tx = await oracle.updatePrices(crypto.ethUsd, crypto.btcUsd, xauUsd);
    console.log(`  Tx sent: ${tx.hash}`);
    await tx.wait();
    console.log(`  Confirmed at block ${tx.blockNumber}`);
  } catch (e) {
    console.error("  Update failed:", e.reason || e.message);
  }
}

// Jalankan sekarang, lalu setiap 15 menit
await updatePrices();
setInterval(updatePrices, 15 * 60 * 1000);
console.log("Keeper running... (update every 15 min)");

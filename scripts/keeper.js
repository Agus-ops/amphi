import { ethers } from "ethers";
import dotenv from "dotenv";
import fs from "fs";

dotenv.config({ path: "/opt/amphi/.env" });

const RPC_URL = process.env.GIWA_RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

if (!RPC_URL || !PRIVATE_KEY) {
    console.error("Missing GIWA_RPC_URL or PRIVATE_KEY in .env");
    process.exit(1);
}

const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Oracle v1.0.0 (6 feed)
const ORACLE = "0x97791AaC465eBe648288201Ef061186D035BCf0f";

const oracleAbi = [
    "function updateCryptoPrices(uint256 ethUsd, uint256 btcUsd, uint256 solUsd) external",
    "function updateCommodityPrices(uint256 xauUsd, uint256 xagUsd, uint256 xptUsd) external",
    "function lastUpdate() external view returns (uint256)",
    "function isStale() external view returns (bool)"
];

const oracle = new ethers.Contract(ORACLE, oracleAbi, wallet);

// Fetch crypto prices from CoinGecko
async function getCryptoPrices() {
    try {
        const res = await fetch("https://api.coingecko.com/api/v3/simple/price?ids=ethereum,bitcoin,solana&vs_currencies=usd");
        const data = await res.json();
        return {
            ethUsd: Math.round(data.ethereum.usd * 1e8),
            btcUsd: Math.round(data.bitcoin.usd * 1e8),
            solUsd: Math.round(data.solana.usd * 1e8)
        };
    } catch (e) {
        console.error("CoinGecko fetch failed:", e.message);
        return null;
    }
}

// Fetch metal prices from gold-api.com (free, no key needed)
async function getMetalPrices() {
    try {
        const [xauRes, xagRes, xptRes] = await Promise.all([
            fetch("https://api.gold-api.com/price/XAU/USD"),
            fetch("https://api.gold-api.com/price/XAG/USD"),
            fetch("https://api.gold-api.com/price/XPT/USD")
        ]);
        const xau = await xauRes.json();
        const xag = await xagRes.json();
        const xpt = await xptRes.json();
        return {
            xauUsd: Math.round(xau.price * 1e8),
            xagUsd: Math.round(xag.price * 1e8),
            xptUsd: Math.round(xpt.price * 1e8)
        };
    } catch (e) {
        console.error("Metal API fetch failed:", e.message);
        return null;
    }
}

async function updatePrices() {
    const now = new Date().toISOString();
    console.log(`[${now}] Fetching prices...`);

    const [crypto, metals] = await Promise.all([
        getCryptoPrices(),
        getMetalPrices()
    ]);

    if (!crypto) {
        console.log("  Crypto fetch failed, skipping...");
        return;
    }
    if (!metals) {
        console.log("  Metal fetch failed, skipping...");
        return;
    }

    console.log(`  ETH: $${crypto.ethUsd / 1e8}`);
    console.log(`  BTC: $${crypto.btcUsd / 1e8}`);
    console.log(`  SOL: $${crypto.solUsd / 1e8}`);
    console.log(`  XAU: $${metals.xauUsd / 1e8}/oz`);
    console.log(`  XAG: $${metals.xagUsd / 1e8}/oz`);
    console.log(`  XPT: $${metals.xptUsd / 1e8}/oz`);

    try {
        // Update crypto prices
        const tx1 = await oracle.updateCryptoPrices(
            crypto.ethUsd,
            crypto.btcUsd,
            crypto.solUsd
        );
        console.log(`  Crypto tx sent: ${tx1.hash}`);
        await tx1.wait();
        console.log(`  Crypto tx confirmed`);

        // Update commodity prices
        const tx2 = await oracle.updateCommodityPrices(
            metals.xauUsd,
            metals.xagUsd,
            metals.xptUsd
        );
        console.log(`  Commodity tx sent: ${tx2.hash}`);
        await tx2.wait();
        console.log(`  Commodity tx confirmed`);

        console.log(`[${now}] All prices updated successfully.`);
    } catch (e) {
        console.error(`  Update failed:`, e.reason || e.message);
    }
}

// Jalankan sekarang, lalu setiap 15 menit
console.log("Amphi Keeper v1.0.0 started. Updating every 15 minutes...");
updatePrices();
setInterval(updatePrices, 15 * 60 * 1000);

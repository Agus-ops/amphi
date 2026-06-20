import { ethers } from "ethers";
import dotenv from "dotenv";
dotenv.config({ path: "/opt/amphi/.env" });

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const RPC_URL = process.env.GIWA_RPC_URL;
const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

const FAUCET = "0x2b1451b7A8F5C60B6A4bea112854c6aF536Fcf83";
const PREMIUM = "0x45a02F53e423BDeE1f17bC351Df4bA846f88ae7B";
const ORACLE = "0xFF5A696a85734205360A04D0005Eb666dE7a9B08";
const mUSDC = "0x31783d58369E5308174a13c264076ef8938260Bb";
const mETH = "0x01f79590Ce1359f4Ae5863057Fa0538a9B399e83";
const mGold = "0x1edB1E3C0740d3E371ecf0F5bB5af2E028afE6bc";
const mBTC = "0x8a96fB4D38715c152092271fa9a86fd97A029045";

const oracleAbi = [
  "function isStale() external view returns (bool)",
  "function getGoldPricePerGram() external view returns (uint256)",
  "function ethUsd() external view returns (uint256)",
  "function btcUsd() external view returns (uint256)",
  "function lastUpdate() external view returns (uint256)"
];
const faucetAbi = ["function claim() external", "function claimed(address) external view returns (bool)"];
const premiumAbi = ["function mintGold() external payable"];
const tokenAbi = ["function balanceOf(address) view returns (uint256)"];

async function main() {
  console.log("=== UJI ORACLE + FAUCET + PREMIUM ===\n");

  // 1. Cek Oracle
  console.log("1. CEK ORACLE");
  const oracle = new ethers.Contract(ORACLE, oracleAbi, provider);
  const stale = await oracle.isStale();
  console.log("   Stale:", stale);
  if (stale) {
    console.log("   ❌ Harga basi! Tunggu keeper update dulu.");
    return;
  }
  const ethPrice = await oracle.ethUsd();
  const btcPrice = await oracle.btcUsd();
  const goldPrice = await oracle.getGoldPricePerGram();
  const lastUpdate = await oracle.lastUpdate();
  console.log(`   ETH: $${Number(ethPrice)/1e8}, BTC: $${Number(btcPrice)/1e8}, XAU: $${Number(goldPrice)/1e18}/gram`);
  console.log(`   Last update: ${new Date(Number(lastUpdate)*1000).toISOString()}`);
  console.log("   ✅ Oracle OK\n");

  // 2. Klaim Faucet
  console.log("2. KLAIM FAUCET");
  const faucet = new ethers.Contract(FAUCET, faucetAbi, wallet);
  const alreadyClaimed = await faucet.claimed(wallet.address);
  if (alreadyClaimed) {
    console.log("   ⚠️ Sudah pernah klaim, skip.");
  } else {
    try {
      const tx = await faucet.claim();
      console.log("   Tx:", tx.hash);
      await tx.wait();
      console.log("   ✅ Klaim sukses");
    } catch (e) {
      console.log("   ❌ Gagal:", e.reason || e.message);
    }
  }
  
  // Cek saldo
  const usdc = new ethers.Contract(mUSDC, tokenAbi, provider);
  const btc = new ethers.Contract(mBTC, tokenAbi, provider);
  const eth = new ethers.Contract(mETH, tokenAbi, provider);
  const gold = new ethers.Contract(mGold, tokenAbi, provider);
  console.log(`   mUSDC: ${ethers.formatUnits(await usdc.balanceOf(wallet.address), 18)}`);
  console.log(`   mBTC: ${ethers.formatUnits(await btc.balanceOf(wallet.address), 18)}`);
  console.log(`   mETH: ${ethers.formatUnits(await eth.balanceOf(wallet.address), 18)}`);
  console.log(`   mGold: ${ethers.formatUnits(await gold.balanceOf(wallet.address), 18)}\n`);

  // 3. Beli mGold via Premium
  console.log("3. BELI mGold (PREMIUM)");
  const premium = new ethers.Contract(PREMIUM, premiumAbi, wallet);
  try {
    const tx = await premium.mintGold({ value: ethers.parseEther("0.01") });
    console.log("   Tx:", tx.hash);
    await tx.wait();
    const newGold = await gold.balanceOf(wallet.address);
    console.log(`   mGold setelah beli: ${ethers.formatUnits(newGold, 18)}`);
    console.log("   ✅ Beli sukses\n");
  } catch (e) {
    console.log("   ❌ Gagal:", e.reason || e.message);
    if (e.reason === "NO_LOCKERS") {
      console.log("   (Butuh locker di vault dulu. PoolSeeder sudah buat 1 locker.)");
    }
  }

  console.log("=== UJI SELESAI ===");
}

main().catch(console.error);

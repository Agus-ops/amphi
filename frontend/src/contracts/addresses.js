// Amphi v1.0.0 — All Contract Addresses (GIWA Sepolia)
// Network: GIWA Sepolia (testnet)
// Chain ID: 91342

export const CHAIN_ID = 91342;

export const ADDRESSES = {
  // === Core Contracts ===
  multisig: "0x1a7FD5A5985291C6eC5CaA09cC4aE88E3EA15da2",
  oracle: "0x97791AaC465eBe648288201Ef061186D035BCf0f",
  factory: "0xEDC7455a84DCf698415e3F88C780E824300D6854",
  router: "0x77609Cef0019A377A1E4986Cb6d818677b26d3E5",
  registry: "0x0188E12168F15aBa5138aaaAa6AAfBf412C3cE95",

  // === Faucets ===
  oracleFaucet: "0xe56eD7b603CbCeD96a66b07d476CD09CdB908256",
  premiumFaucet: "0xbb870B14601C01106545E33D3Bee1539690E13a3",

  // === Tokens (18 Decimals) ===
  mUSDC: "0xEaABc4B73A3cf2111E0E977bC761Ee2bF04ed69D",
  mBTC: "0xe9697C869F2324Fc4d1AFB5Cb25468c2652942FB",
  mETH: "0x018F4De8dF24Bc356A9B6a51149e5f72A2Bb3ED9",
  mSOL: "0xe2B81f94CaE2c4Ac0c05b398fAF9A2B2AF0D920C",
  mGold: "0x9bCC75105b5d8f74918844782263350408Aa9bbb",
  mSilver: "0xFAEBbFC63520182B7b7C9566d9D765960ECDC2aD",
  mPlatinum: "0x1819F63CC557a92DE7C7fc2f854e08B9fA2C8b8a",

  // === Liquidity Pools ===
  USDC_BTC: "0x92C2aB45E0d3Cf0a87aBa6CeFe475F5F8D5e4936",
  USDC_ETH: "0xE9F0E0770fFee225503d082009369D7A144e8aA2",
  USDC_SOL: "0x197a21aA919f4e932D6D89Ea3Af31c655ffDD3CD",
  USDC_Gold: "0xBc0783CFba35423f72Bb56fb94b9bE1456e47e60",
  USDC_Silver: "0xFFBb12119DaAC7628eA6c57C3683EB6d4f8D8Ff1",
  USDC_Platinum: "0xbF4eBbc51140E87D189D76aAab43D3783C0fd235",

  // === Vaults ===
  goldVault: "0xFB84983BFE23f064fe71cBB3E962A2dCd99c5765",
  silverVault: "0x5276404eE0b49146263E6F42A8d04DB295403e50",
  platinumVault: "0x4AD27E4a743aF8bb5bEC04A73A6F37C1327028da",

  // === Reward Pools ===
  goldRewardPool: "0xFaFF58e583cA18Da2f0F14459E00423B4AE6eff3",
  silverRewardPool: "0xf3365cb08046FA7E44af83e839bdb785d3ab0e16",
  platinumRewardPool: "0x3FeF73be06799fB60D919F997f724F2f9179F59E",
};

// === Arrays for UI Mapping ===
export const TOKENS = [
  { symbol: "mUSDC", address: ADDRESSES.mUSDC, decimals: 18, name: "USD Coin" },
  { symbol: "mBTC", address: ADDRESSES.mBTC, decimals: 18, name: "Bitcoin" },
  { symbol: "mETH", address: ADDRESSES.mETH, decimals: 18, name: "Ethereum" },
  { symbol: "mSOL", address: ADDRESSES.mSOL, decimals: 18, name: "Solana" },
  { symbol: "mGold", address: ADDRESSES.mGold, decimals: 18, name: "Gold" },
  { symbol: "mSilver", address: ADDRESSES.mSilver, decimals: 18, name: "Silver" },
  { symbol: "mPlatinum", address: ADDRESSES.mPlatinum, decimals: 18, name: "Platinum" },
];

export const POOLS = [
  { token0: "mUSDC", token1: "mBTC", address: ADDRESSES.USDC_BTC },
  { token0: "mUSDC", token1: "mETH", address: ADDRESSES.USDC_ETH },
  { token0: "mUSDC", token1: "mSOL", address: ADDRESSES.USDC_SOL },
  { token0: "mUSDC", token1: "mGold", address: ADDRESSES.USDC_Gold },
  { token0: "mUSDC", token1: "mSilver", address: ADDRESSES.USDC_Silver },
  { token0: "mUSDC", token1: "mPlatinum", address: ADDRESSES.USDC_Platinum },
];

export const VAULTS = [
  { symbol: "mGold", address: ADDRESSES.goldVault, rewardPool: ADDRESSES.goldRewardPool },
  { symbol: "mSilver", address: ADDRESSES.silverVault, rewardPool: ADDRESSES.silverRewardPool },
  { symbol: "mPlatinum", address: ADDRESSES.platinumVault, rewardPool: ADDRESSES.platinumRewardPool },
];

export const OPERATORS = [];

// === Explorer Helpers ===
export const explorerTx = (hash) => `https://sepolia-explorer.giwa.io/tx/${hash}`;
export const explorerAddr = (addr) => `https://sepolia-explorer.giwa.io/address/${addr}`;

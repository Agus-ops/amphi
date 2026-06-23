# Amphi v1.0.0 — Sandbox Economy Simulator

A two‑layer economic sandbox built on **GIWA Sepolia** (Chain ID 91342).  
Simulates capital rotation between crypto risk‑on assets and commodity safe‑haven assets with real‑time oracle pricing, an AMM, yield vaults, and a premium faucet.

**Live since June 2026 · All contracts verified on Blockscout**

---

## Overview

| Layer | Description |
|-------|-------------|
| **Official Economy** | 7 oracle‑backed assets (crypto + commodities), 6 liquidity pools, 3 yield vaults |
| **Community Economy** | Permissionless token factory & pools (phase 2) |

---

## Features

- **Faucet** — Claim 7 tokens worth $500 each (one‑time per address)
- **Premium Faucet** — Buy Gold, Silver, Platinum with ETH (real‑time oracle pricing, 1.5% fee, $1,000/tx limit)
- **Swap** — Single‑hop & multihop swaps via RouterV3 (6 official pools, 0.3% fee)
- **Liquidity** — Add/remove liquidity to any official pool
- **Vault** — Lock commodities (Gold/Silver/Platinum) for 7/15/30 days and earn ETH rewards
- **Governance** — Multisig wallet with timelock (24h delay)

---

## Contract Addresses

| Contract | Address |
|----------|---------|
| AmphiMultisig | `0x1a7FD5A5985291C6eC5CaA09cC4aE88E3EA15da2` |
| AmphiOracle | `0x97791AaC465eBe648288201Ef061186D035BCf0f` |
| AmphiRouterV3 | `0x77609Cef0019A377A1E4986Cb6d818677b26d3E5` |
| AmphiFactory | `0xEDC7455a84DCf698415e3F88C780E824300D6854` |
| AmphiRegistry | `0x0188E12168F15aBa5138aaaAa6AAfBf412C3cE95` |

### Tokens (all 18 decimals)

| Token | Address |
|-------|---------|
| mUSDC | `0xEaABc4B73A3cf2111E0E977bC761Ee2bF04ed69D` |
| mBTC | `0xe9697C869F2324Fc4d1AFB5Cb25468c2652942FB` |
| mETH | `0x018F4De8dF24Bc356A9B6a51149e5f72A2Bb3ED9` |
| mSOL | `0xe2B81f94CaE2c4Ac0c05b398fAF9A2B2AF0D920C` |
| mGold | `0x9bCC75105b5d8f74918844782263350408Aa9bbb` |
| mSilver | `0xFAEBbFC63520182B7b7C9566d9D765960ECDC2aD` |
| mPlatinum | `0x1819F63CC557a92DE7C7fc2f854e08B9fA2C8b8a` |

### Official Pools (all seeded with ~$200K per side)

| Pool | Address |
|------|---------|
| USDC/BTC | `0x92C2aB45E0d3Cf0a87aBa6CeFe475F5F8D5e4936` |
| USDC/ETH | `0xE9F0E0770fFee225503d082009369D7A144e8aA2` |
| USDC/SOL | `0x197a21aA919f4e932D6D89Ea3Af31c655ffDD3CD` |
| USDC/Gold | `0xBc0783CFba35423f72Bb56fb94b9bE1456e47e60` |
| USDC/Silver | `0xFFBb12119DaAC7628eA6c57C3683EB6d4f8D8Ff1` |
| USDC/Platinum | `0xbF4eBbc51140E87D189D76aAab43D3783C0fd235` |

### Vaults & Reward Pools

| Commodity | Vault | Reward Pool |
|-----------|-------|-------------|
| Gold | `0xFB84983BFE23f064fe71cBB3E962A2dCd99c5765` | `0xFaFF58e583cA18Da2f0F14459E00423B4AE6eff3` |
| Silver | `0x5276404eE0b49146263E6F42A8d04DB295403e50` | `0xf3365cb08046FA7E44af83e839bdb785d3ab0e16` |
| Platinum | `0x4AD27E4a743aF8bb5bEC04A73A6F37C1327028da` | `0x3FeF73be06799fB60D919F997f724F2f9179F59E` |

### Faucets

| Faucet | Address |
|--------|---------|
| OracleFaucet (free) | `0xe56eD7b603CbCeD96a66b07d476CD09CdB908256` |
| PremiumCommodityFaucet | `0xbb870B14601C01106545E33D3Bee1539690E13a3` |

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Smart Contracts | Solidity 0.8.20 · Foundry |
| Oracle Keeper | Node.js · PM2 · CoinGecko API · GoldAPI.io |
| Frontend | React · Vite · wagmi · viem · Tailwind CSS |
| Blockchain | GIWA Sepolia (OP Stack L2) · Chain ID 91342 |

---

## Getting Started

### Deploy contracts
forge build
forge script script/FullDeployFinal.s.sol --rpc-url $RPC_URL --private-key $PK --broadcast --legacy --slow -vvv

### Run oracle keeper
pm2 start scripts/keeper.js --name amphi-keeper
pm2 save

### Run frontend
cd frontend
npm install
npm run dev

---

## Audit & Verification

All 13 core contracts are fully verified on Blockscout GIWA and underwent AI-assisted security reviews and static analysis (via Claude, Gemini, Qwen, DeepSeek) during development. *Note: This is a sandbox project and has not undergone a formal manual audit by a Web3 security firm.*

· View AmphiOracle on Explorer
· View AmphiRouterV3 on Explorer
· View all verified contracts

---

## Roadmap

· Core contracts (Multisig, Oracle, Factory, Router, Pair, Tokens)
· Yield Vaults (Gold, Silver, Platinum)
· Premium Commodity Faucet (3 assets)
· Free Oracle Faucet (7 assets)
· Registry for official assets
· Timelock governance (24h delay)
· Initial liquidity seeding ($200K per pool)
· Community token factory (phase 2)
· Governance dashboard
· Mobile‑responsive UI

---

## License

MIT — built by Agus for the GIWA ecosystem.

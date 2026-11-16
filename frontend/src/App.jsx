import { useState, useEffect } from "react";
import { useAccount, useChainId, useReadContract } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { Droplets, ArrowLeftRight, Lock, User, ShieldCheck } from "lucide-react";
import { FaucetPanel } from "./components/FaucetPanel";
import { SwapPanel } from "./components/SwapPanel";
import { VaultPanel } from "./components/VaultPanel";
import { AdminPanel } from "./components/AdminPanel";
import { ProfilePanel } from "./components/ProfilePanel";

// INI YANG DIBENARKAN: Menggunakan "./" bukan "../"
import { GIWA_SEPOLIA } from "./config/chains";
import { ORACLE } from "./contracts/contracts";
import { ORACLE_ABI } from "./contracts/abis";

import "./styles/amphi-theme.css";

const TABS = ["Faucet", "Swap", "Vault", "Profile", "Admin"];

const TAB_ICONS = {
  Faucet: Droplets,
  Swap: ArrowLeftRight,
  Vault: Lock,
  Profile: User,
  Admin: ShieldCheck,
};

function fmtUsd(v, dp) {
  if (v == null || !Number.isFinite(v)) return "—";
  return "$" + v.toLocaleString("en-US", { minimumFractionDigits: dp, maximumFractionDigits: dp });
}

export default function App() {
  const { isConnected } = useAccount();
  const chainId = useChainId();
  const isRightChain = chainId === GIWA_SEPOLIA.id;
  const [activeTab, setActiveTab] = useState("Faucet");

  // Oracle split into individual getters: crypto = 8 decimals, commodities = per-gram, 18 decimals.
  const TROY_OZ_IN_GRAMS = 31.1034768;

  const { data: ethUsdData } = useReadContract({ address: ORACLE, abi: ORACLE_ABI, functionName: "getEthUsd" });
  const { data: btcUsdData } = useReadContract({ address: ORACLE, abi: ORACLE_ABI, functionName: "getBtcUsd" });
  const { data: solUsdData } = useReadContract({ address: ORACLE, abi: ORACLE_ABI, functionName: "getSolUsd" });
  const { data: goldGramData } = useReadContract({ address: ORACLE, abi: ORACLE_ABI, functionName: "getGoldPricePerGram" });
  const { data: silverGramData } = useReadContract({ address: ORACLE, abi: ORACLE_ABI, functionName: "getSilverPricePerGram" });
  const { data: platinumGramData } = useReadContract({ address: ORACLE, abi: ORACLE_ABI, functionName: "getPlatinumPricePerGram" });
  const { data: oracleStaleData } = useReadContract({ address: ORACLE, abi: ORACLE_ABI, functionName: "isStale", query: { refetchInterval: 30000 } });
  const { data: oracleLastUpdate } = useReadContract({ address: ORACLE, abi: ORACLE_ABI, functionName: "lastUpdate", query: { refetchInterval: 30000 } });

  const oracleIsStale = oracleStaleData === true;
  const lastUpdateTs = oracleLastUpdate ? Number(oracleLastUpdate) : null;

  const ethNum = ethUsdData ? Number(ethUsdData) / 1e8 : null;
  const btcNum = btcUsdData ? Number(btcUsdData) / 1e8 : null;
  const solNum = solUsdData ? Number(solUsdData) / 1e8 : null;
  const goldOzNum = goldGramData ? (Number(goldGramData) / 1e18) * TROY_OZ_IN_GRAMS : null;
  const silverOzNum = silverGramData ? (Number(silverGramData) / 1e18) * TROY_OZ_IN_GRAMS : null;
  const platinumOzNum = platinumGramData ? (Number(platinumGramData) / 1e18) * TROY_OZ_IN_GRAMS : null;

  const PRICES = [
    { label: "ETH", value: fmtUsd(ethNum, 0) },
    { label: "BTC", value: fmtUsd(btcNum, 0) },
    { label: "SOL", value: fmtUsd(solNum, 2) },
    { label: "XAU · Gold", value: fmtUsd(goldOzNum, 0), unit: "/oz" },
    { label: "XAG · Silver", value: fmtUsd(silverOzNum, 2), unit: "/oz" },
    { label: "XPT · Platinum", value: fmtUsd(platinumOzNum, 0), unit: "/oz" },
  ];

  const [btcDominance, setBtcDominance] = useState(null);
  useEffect(() => {
    let cancelled = false;
    async function fetchDominance() {
      try {
        const res = await fetch("https://api.coingecko.com/api/v3/global");
        const json = await res.json();
        const dom = json?.data?.market_cap_percentage?.btc;
        if (!cancelled && typeof dom === "number") setBtcDominance(dom);
      } catch {}
    }
    fetchDominance();
    const id = setInterval(fetchDominance, 5 * 60 * 1000); // refresh every 5 min
    return () => { cancelled = true; clearInterval(id); };
  }, []);

  const btcGoldRatio = btcNum && goldOzNum ? btcNum / goldOzNum : null;

  const RATIO_LOW = 10;   // fully risk-off (BTC/Gold ratio)
  const RATIO_HIGH = 60;  // fully risk-on (BTC/Gold ratio)
  const DOM_LOW = 30;     // low BTC dominance => altseason => risk-on
  const DOM_HIGH = 70;    // high BTC dominance => flight to BTC within crypto => risk-off

  let ratioScore = null;
  if (btcGoldRatio != null) {
    const pct = ((btcGoldRatio - RATIO_LOW) / (RATIO_HIGH - RATIO_LOW)) * 100;
    ratioScore = Math.min(Math.max(100 - pct, 0), 100); // invert: higher ratio = more risk-on (lower score = left/risk-on)
  }

  let domScore = null;
  if (btcDominance != null) {
    const pct = ((btcDominance - DOM_LOW) / (DOM_HIGH - DOM_LOW)) * 100;
    domScore = Math.min(Math.max(100 - pct, 0), 100); // invert: lower dominance = more risk-on
  }

  let markerPos = 50;
  if (ratioScore != null && domScore != null) {
    markerPos = Math.min(Math.max(0.6 * ratioScore + 0.4 * domScore, 5), 95);
  } else if (ratioScore != null) {
    markerPos = Math.min(Math.max(ratioScore, 5), 95);
  }

  return (
    <div className="amphi-app">
      <header className="amphi-header">
        <div className="amphi-brand">
          <svg className="amphi-logo" width="30" height="30" viewBox="0 0 32 32" fill="none" aria-hidden="true">
            <circle cx="13.5" cy="16" r="7.5" stroke="#8f9299" strokeWidth="2.4" />
            <circle cx="19.5" cy="16" r="7.5" stroke="#c8a45d" strokeWidth="2.4" />
          </svg>
          <span className="amphi-wordmark"><span className="am">Am</span><span className="phi">phi</span></span>
        </div>
        <div className="amphi-header-actions">
          <span className="amphi-net-badge"><span className="amphi-net-dot"></span>GIWA Sepolia · Testnet</span>
          <ConnectButton />
        </div>
      </header>

      <section className="amphi-prices" aria-label="Live oracle prices">
        <div className="amphi-prices-head"><span>Live oracle prices</span><span className={`amphi-oracle-status ${oracleIsStale ? "is-stale" : ""}`}><span className="amphi-oracle-dot"></span>{oracleIsStale ? "Oracle stale" : "Live"}{lastUpdateTs ? ` · updated ${new Date(lastUpdateTs * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}` : ""}</span></div>
        <div className="amphi-prices-grid">
          {PRICES.map((p) => (
            <div className="amphi-price-item" key={p.label}>
              <span className="amphi-price-label">{p.label}</span>
              <span className="amphi-price-value">{p.value}{p.unit && <span className="amphi-price-unit">{p.unit}</span>}</span>
            </div>
          ))}
        </div>
      </section>

      <div className="amphi-gauge-wrap">
        <div className="amphi-gauge-label"><span>RISK-ON</span><span>RISK-OFF</span></div>
        <div
          className="amphi-gauge-track"
          style={{
            background: `linear-gradient(90deg, var(--crypto) 0%, var(--crypto) ${markerPos}%, var(--gold) ${markerPos}%, var(--gold) 100%)`,
            transition: "background 1s ease-in-out",
          }}
        >
          <div className="amphi-gauge-marker" style={{ left: `${markerPos}%`, transition: "left 1s ease-in-out" }}></div>
        </div>
      </div>

      <div className="amphi-body-layout">
        <div className="amphi-sidebar">
          {TABS.map((tab) => {
            const Icon = TAB_ICONS[tab];
            return (
              <button key={tab} className={`amphi-side-item ${activeTab === tab ? "active" : ""}`} onClick={() => setActiveTab(tab)} type="button">
                <Icon size={15} />{tab}
              </button>
            );
          })}
        </div>
        <div className="amphi-main">
          <div className="amphi-tabs">
            {TABS.map((tab) => {
              const Icon = TAB_ICONS[tab];
              return (
                <button key={tab} className={`amphi-tab ${activeTab === tab ? "active" : ""}`} onClick={() => setActiveTab(tab)} type="button">
                  <Icon size={14} />{tab}
                </button>
              );
            })}
          </div>
          <div className="amphi-content">
            <div className="amphi-grid">
              {activeTab === "Faucet" && <FaucetPanel isConnected={isConnected} isRightChain={isRightChain} />}
              {activeTab === "Swap" && <SwapPanel isConnected={isConnected} isRightChain={isRightChain} />}
              {activeTab === "Vault" && <VaultPanel isConnected={isConnected} isRightChain={isRightChain} />}
              {activeTab === "Profile" && <ProfilePanel isConnected={isConnected} isRightChain={isRightChain} />}
              {activeTab === "Admin" && <AdminPanel isConnected={isConnected} isRightChain={isRightChain} />}
            </div>
          </div>
        </div>
      </div>

      <footer className="amphi-footer">
        <div>
          AmphiOracle:{" "}
          <a href={`${GIWA_SEPOLIA.explorerUrl}/address/0x97791AaC465eBe648288201Ef061186D035BCf0f`} target="_blank" rel="noreferrer">
            0x9779…BCf0f ↗
          </a>
          {" · "}AmphiRouterV3:{" "}
          <a href={`${GIWA_SEPOLIA.explorerUrl}/address/0x77609Cef0019A377A1E4986Cb6d818677b26d3E5`} target="_blank" rel="noreferrer">
            0x7760…6d3E5 ↗
          </a>
        </div>
        <div>
          <a href="https://github.com/Agus-ops/amphi" target="_blank" rel="noreferrer">GitHub ↗</a>
          {" · "}GIWA Sepolia · Testnet
        </div>
      </footer>
    </div>
  );
}

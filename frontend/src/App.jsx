import { useState, useEffect } from "react";
import { useAccount, useChainId, useReadContract } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
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

  const ethNum = ethUsdData ? Number(ethUsdData) / 1e8 : null;
  const btcNum = btcUsdData ? Number(btcUsdData) / 1e8 : null;
  const solNum = solUsdData ? Number(solUsdData) / 1e8 : null;
  const goldOzNum = goldGramData ? (Number(goldGramData) / 1e18) * TROY_OZ_IN_GRAMS : null;
  const silverOzNum = silverGramData ? (Number(silverGramData) / 1e18) * TROY_OZ_IN_GRAMS : null;
  const platinumOzNum = platinumGramData ? (Number(platinumGramData) / 1e18) * TROY_OZ_IN_GRAMS : null;

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
      <div className="amphi-header">
        <div className="amphi-brand">
          <svg className="amphi-logo" width="26" height="26" viewBox="0 0 26 26" fill="none">
            <circle cx="10" cy="13" r="8" fill="#6C8CFF" opacity="0.9" />
            <circle cx="16" cy="13" r="8" fill="#D9A85C" opacity="0.9" />
          </svg>
          <span className="amphi-wordmark"><span className="am">Am</span><span className="phi">phi</span></span>
        </div>
        <ConnectButton />
      </div>

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
        <div className="amphi-gauge-note">
          {ethNum && btcNum && solNum && goldOzNum && silverOzNum && platinumOzNum
            ? `ETH $${ethNum.toFixed(0)} · BTC $${btcNum.toFixed(0)} · SOL $${solNum.toFixed(2)}  |  XAU $${goldOzNum.toFixed(0)}/oz · XAG $${silverOzNum.toFixed(2)}/oz · XPT $${platinumOzNum.toFixed(0)}/oz`
            : "Sandbox economy on GIWA Sepolia"}
        </div>
      </div>

      <div className="amphi-body-layout">
        <div className="amphi-sidebar">
          {TABS.map((tab) => (
            <button key={tab} className={`amphi-side-item ${activeTab === tab ? "active" : ""}`} onClick={() => setActiveTab(tab)} type="button">
              <span className="amphi-side-dot"></span>{tab}
            </button>
          ))}
        </div>
        <div className="amphi-main">
          <div className="amphi-tabs">
            {TABS.map((tab) => (
              <button key={tab} className={`amphi-tab ${activeTab === tab ? "active" : ""}`} onClick={() => setActiveTab(tab)} type="button">{tab}</button>
            ))}
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

      <div style={{ textAlign: "center", padding: "20px", fontSize: 11, color: "var(--text-dim)" }}>
        AmphiOracle:{" "}
        <a href={`${GIWA_SEPOLIA.explorerUrl}/address/0x97791AaC465eBe648288201Ef061186D035BCf0f`} target="_blank" rel="noreferrer">
          0x9779…BCf0f ↗
        </a>
        {" · "}AmphiRouterV3:{" "}
        <a href={`${GIWA_SEPOLIA.explorerUrl}/address/0x77609Cef0019A377A1E4986Cb6d818677b26d3E5`} target="_blank" rel="noreferrer">
          0x7760…6d3E5 ↗
        </a>
      </div>
    </div>
  );
}

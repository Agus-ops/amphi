import { Fragment, useEffect, useRef, useState } from "react";
import { useAccount, usePublicClient, useWriteContract } from "wagmi";
import { formatUnits, parseEther } from "viem";
import { ExternalLink, Gift, RefreshCw, Coins } from "lucide-react";
import { ORACLE, ORACLE_FAUCET, PREMIUM_FAUCET } from "../contracts/contracts";
import { ORACLE_ABI, FAUCET_ABI, PREMIUM_ABI } from "../contracts/abis";
import { GIWA_SEPOLIA } from "../config/chains";

function fmtAmt(v, dp = 4) {
  if (!Number.isFinite(v) || v <= 0) return "0.00";
  return new Intl.NumberFormat(undefined, { maximumFractionDigits: dp }).format(v);
}

export function FaucetPanel({ isConnected, isRightChain }) {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { writeContractAsync } = useWriteContract();

  const [oracleStale, setOracleStale] = useState(false);
  const [alreadyClaimed, setAlreadyClaimed] = useState(false);
  
  const [commType, setCommType] = useState("Gold");
  const [remainingBudget, setRemainingBudget] = useState(0);
  const [maxPerTx, setMaxPerTx] = useState(0);
  const [ethAmount, setEthAmount] = useState("");
  
  const [busyFaucet, setBusyFaucet] = useState(false);
  const [busyPremium, setBusyPremium] = useState(false);
  const [toast, setToast] = useState(null);
  const [lastTx, setLastTx] = useState(null);
  const toastTimer = useRef(null);

  const explorerTx = (hash) => `${GIWA_SEPOLIA.explorerUrl}/tx/${hash}`;

  function showToast(kind, text, hash = null) {
    setToast({ kind, text, hash });
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 8000);
  }

  useEffect(() => {
    if (!publicClient) return;
    let cancelled = false;
    async function refresh() {
      try {
        const stale = await publicClient.readContract({ address: ORACLE, abi: ORACLE_ABI, functionName: "isStale" });
        if (!cancelled) setOracleStale(Boolean(stale));
      } catch {}
      if (address) {
        try {
          const claimed = await publicClient.readContract({ address: ORACLE_FAUCET, abi: FAUCET_ABI, functionName: "claimed", args: [address] });
          if (!cancelled) setAlreadyClaimed(Boolean(claimed));
        } catch {}
        try {
          const ethUsd = await publicClient.readContract({ address: ORACLE, abi: ORACLE_ABI, functionName: "getEthUsd" });
          const targetUsdPerTx = await publicClient.readContract({ address: PREMIUM_FAUCET, abi: PREMIUM_ABI, functionName: "TARGET_USD_PER_TX" });
          const maxDailyUsd = await publicClient.readContract({ address: PREMIUM_FAUCET, abi: PREMIUM_ABI, functionName: "MAX_DAILY_USD" });
          const spent = await publicClient.readContract({ address: PREMIUM_FAUCET, abi: PREMIUM_ABI, functionName: "dailySpent", args: [address] });
          const lastDayTs = await publicClient.readContract({ address: PREMIUM_FAUCET, abi: PREMIUM_ABI, functionName: "lastDay", args: [address] });

          const ethUsdNum = Number(ethUsd) / 1e8; // oracle 8 decimals
          const todayIdx = Math.floor(Date.now() / 86400000);
          const lastDayIdx = Number(lastDayTs);
          const spentTodayUsd = lastDayIdx === todayIdx ? Number(spent) / 1e8 : 0; // contract usd values are 8 decimals

          const maxTxUsd = Number(targetUsdPerTx) / 1e8;
          const maxDailyUsdNum = Number(maxDailyUsd) / 1e8;
          const remainingUsd = Math.max(0, maxDailyUsdNum - spentTodayUsd);

          if (!cancelled && ethUsdNum > 0) {
            setMaxPerTx(maxTxUsd / ethUsdNum);
            setRemainingBudget(remainingUsd / ethUsdNum);
          }
        } catch {}
      }
    }
    refresh();
    const id = setInterval(refresh, 15000);
    return () => { cancelled = true; clearInterval(id); };
  }, [publicClient, address]);

  const ethNum = parseFloat(String(ethAmount).replace(",", ".")) || 0;
  const canClaim = isConnected && isRightChain && !oracleStale && !alreadyClaimed && !busyFaucet;
  const canBuy = isConnected && isRightChain && !oracleStale && !busyPremium && ethNum > 0 && ethNum <= maxPerTx && ethNum <= remainingBudget;

  async function runClaim() {
    if (!address || !publicClient || busyFaucet) return;
    setBusyFaucet(true);
    try {
      const hash = await writeContractAsync({ address: ORACLE_FAUCET, abi: FAUCET_ABI, functionName: "claim" });
      showToast("info", "Claiming 7 tokens…", hash);
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      if (receipt.status === "reverted") showToast("error", "Claim reverted on-chain", hash);
      else { showToast("success", "Faucet claimed successfully ✓", hash); setAlreadyClaimed(true); setLastTx(hash); }
    } catch (err) {
      showToast("error", err?.shortMessage || err?.message || "Claim failed");
    } finally { setBusyFaucet(false); }
  }

  async function runBuyPremium() {
    if (!address || !publicClient || busyPremium) return;
    if (ethNum > maxPerTx) { showToast("error", `Max ${fmtAmt(maxPerTx)} ETH per tx`); return; }
    if (ethNum > remainingBudget) { showToast("error", `Remaining daily quota: ${fmtAmt(remainingBudget)} ETH`); return; }
    
    setBusyPremium(true);
    const fnName = commType === "Gold" ? "mintGold" : commType === "Silver" ? "mintSilver" : "mintPlatinum";
    
    try {
      const hash = await writeContractAsync({ address: PREMIUM_FAUCET, abi: PREMIUM_ABI, functionName: fnName, value: parseEther(String(ethNum)) });
      showToast("info", `Buying m${commType}…`, hash);
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      if (receipt.status === "reverted") showToast("error", "Transaction reverted on-chain", hash);
      else { 
        showToast("success", `Purchase successful ✓`, hash); 
        setRemainingBudget((b) => Math.max(0, b - ethNum)); 
        setLastTx(hash); 
        setEthAmount(""); 
      }
    } catch (err) {
      showToast("error", err?.shortMessage || err?.message || "Purchase failed");
    } finally { setBusyPremium(false); }
  }

  return (
    <Fragment>
      {toast && (
        <div className={`amphi-toast amphi-toast--${toast.kind}`}>
          <span>{toast.text}</span>
          {toast.hash && <a href={explorerTx(toast.hash)} target="_blank" rel="noreferrer">Tx <ExternalLink size={11} /></a>}
        </div>
      )}

      {oracleStale && <div className="amphi-card amphi-notice amphi-notice--warn amphi-notice-full">Oracle prices are updating, transactions paused.</div>}

      <div className="amphi-card amphi-card--crypto">
        <div className="amphi-card-title"><span><Gift size={13} /> Official Faucet</span><small>1× per address</small></div>
        <div className="amphi-card-desc">Claim starter pack of mUSDC, mBTC, mETH, mSOL, mGold, mSilver, and mPlatinum.</div>
        {!isConnected ? <div className="amphi-notice">Connect your wallet to claim</div>
        : !isRightChain ? <div className="amphi-notice amphi-notice--warn">Wrong network — switch to GIWA Sepolia</div>
        : alreadyClaimed ? <div className="amphi-notice">This address has already claimed the faucet</div>
        : <button className="amphi-btn amphi-btn-crypto" onClick={runClaim} disabled={!canClaim}>
            {busyFaucet ? <><RefreshCw size={13} className="spinIcon" /> Processing…</> : "Claim 7 Tokens"}
          </button>}
      </div>

      <div className="amphi-card amphi-card--gold">
        <div className="amphi-card-title"><span><Coins size={13} /> Premium Faucet</span><small>max {fmtAmt(maxPerTx)} ETH/tx</small></div>
        <div style={{ display: "flex", gap: 6, marginBottom: 12 }}>
          {["Gold", "Silver", "Platinum"].map((c) => (
            <button key={c} type="button" onClick={() => setCommType(c)} className="amphi-btn-ghost" style={{ flex: 1, padding: "6px", fontSize: 12, borderRadius: 6, background: commType === c ? "#1C1408" : "transparent", color: commType === c ? "#D9A85C" : "#8A8F9C", borderColor: commType === c ? "#7A6238" : "#1F2530" }}>
              {c}
            </button>
          ))}
        </div>
        <div className="amphi-field">
          <input className="amphi-input" type="number" placeholder="0.00 ETH" value={ethAmount} min="0" max={maxPerTx} step="0.01" onChange={(e) => setEthAmount(e.target.value)} />
        </div>
        
        <div className="amphi-quota-text" style={{ marginTop: 8 }}><span>Daily budget remaining:</span><span>{fmtAmt(remainingBudget, 2)} ETH</span></div>
        
        {!isConnected ? <div className="amphi-notice">Connect your wallet to buy</div>
        : !isRightChain ? <div className="amphi-notice amphi-notice--warn">Wrong network</div>
        : <button className="amphi-btn amphi-btn-gold" onClick={runBuyPremium} disabled={!canBuy}>
            {busyPremium ? <><RefreshCw size={13} className="spinIcon" /> Processing…</> : `Buy m${commType}`}
          </button>}
      </div>

      {lastTx && <div className="amphi-card-desc"><a href={explorerTx(lastTx)} target="_blank" rel="noreferrer">View last tx ↗</a></div>}
    </Fragment>
  );
}

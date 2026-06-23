import { useState, useRef, useEffect } from "react";
import { useAccount, usePublicClient, useWriteContract, useReadContracts } from "wagmi";
import { parseUnits, formatUnits } from "viem";
import { ArrowUpDown, ExternalLink, RefreshCw } from "lucide-react";
import { ADDRESSES, TOKENS, FACTORY, ROUTER, ORACLE } from "../contracts/contracts";
import { ERC20_ABI, ROUTER_ABI, FACTORY_ABI, ORACLE_ABI } from "../contracts/abis";
import { useOfficialTokens } from "../hooks/useOfficialTokens";
import { useReadContract } from "wagmi";
import { GIWA_SEPOLIA } from "../config/chains";

const TOKEN_LIST = [
  { symbol: "mUSDC", address: TOKENS.mUSDC },
  { symbol: "mBTC", address: TOKENS.mBTC },
  { symbol: "mETH", address: TOKENS.mETH },
  { symbol: "mSOL", address: TOKENS.mSOL },
  { symbol: "mGold", address: TOKENS.mGold },
  { symbol: "mSilver", address: TOKENS.mSilver },
  { symbol: "mPlatinum", address: TOKENS.mPlatinum },
];

export function SwapPanel({ isConnected, isRightChain }) {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { writeContractAsync } = useWriteContract();

  const { officialTokens, isLoading: registryLoading } = useOfficialTokens();
  const { data: oracleStale } = useReadContract({ address: ORACLE, abi: ORACLE_ABI, functionName: "isStale" });

  // Fallback ke TOKEN_LIST statis selagi registry belum kebaca, supaya UI tidak kosong.
  const safeTokenList = (!registryLoading && officialTokens.length > 0)
    ? TOKEN_LIST.filter((t) => officialTokens.some((o) => o.address.toLowerCase() === t.address.toLowerCase()))
    : TOKEN_LIST;

  const [tokenIn, setTokenIn] = useState(TOKEN_LIST[0]);
  const [tokenOut, setTokenOut] = useState(TOKEN_LIST[4]);

  const { data: balanceData, refetch: refetchBalances } = useReadContracts({
    contracts: [
      { address: tokenIn.address, abi: ERC20_ABI, functionName: "balanceOf", args: [address] },
      { address: tokenOut.address, abi: ERC20_ABI, functionName: "balanceOf", args: [address] },
    ],
    query: { enabled: !!address },
  });
  const balanceIn = balanceData?.[0]?.result != null ? Number(formatUnits(balanceData[0].result, 18)) : null;
  const balanceOut = balanceData?.[1]?.result != null ? Number(formatUnits(balanceData[1].result, 18)) : null;
  const [amount, setAmount] = useState("");
  const [isDirectRoute, setIsDirectRoute] = useState(true);
  
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useState(null);
  const [lastTx, setLastTx] = useState(null);
  const toastTimer = useRef(null);

  const explorerTx = (hash) => `${GIWA_SEPOLIA.explorerUrl}/tx/${hash}`;

  function showToast(kind, text, hash = null) {
    setToast({ kind, text, hash });
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 8000);
  }

  function flip() { setTokenIn(tokenOut); setTokenOut(tokenIn); }

  useEffect(() => {
    if (!publicClient || tokenIn.address === tokenOut.address) return;
    // Check if direct pool exists
    publicClient.readContract({
      address: FACTORY, abi: FACTORY_ABI, functionName: "getPair", args: [tokenIn.address, tokenOut.address]
    }).then(pair => {
      setIsDirectRoute(pair !== "0x0000000000000000000000000000000000000000");
    }).catch(() => setIsDirectRoute(false));
  }, [publicClient, tokenIn, tokenOut]);

  const amountNum = parseFloat(String(amount).replace(",", ".")) || 0;
  const canSwap = isConnected && isRightChain && !busy && !oracleStale && amountNum > 0 && tokenIn.address !== tokenOut.address;

  const routePath = isDirectRoute || tokenIn.address === TOKENS.mUSDC || tokenOut.address === TOKENS.mUSDC
    ? [tokenIn.address, tokenOut.address]
    : [tokenIn.address, TOKENS.mUSDC, tokenOut.address];

  const routeDisplay = routePath.length === 2 ? `${tokenIn.symbol} → ${tokenOut.symbol}` : `${tokenIn.symbol} → mUSDC → ${tokenOut.symbol}`;

  async function runSwap() {
    if (!address || !publicClient || busy) return;
    if (tokenIn.address === tokenOut.address) { showToast("error", "Select different tokens"); return; }
    setBusy(true);
    try {
      const parsed = parseUnits(String(amountNum), 18);
      const allowance = await publicClient.readContract({
        address: tokenIn.address, abi: ERC20_ABI, functionName: "allowance", args: [address, ROUTER],
      });
      if (allowance < parsed) {
        showToast("info", `Approving ${tokenIn.symbol}…`);
        const ah = await writeContractAsync({ address: tokenIn.address, abi: ERC20_ABI, functionName: "approve", args: [ROUTER, parsed] });
        await publicClient.waitForTransactionReceipt({ hash: ah });
      }
      
      const deadline = BigInt(Math.floor(Date.now() / 1000) + 600);
      const hash = await writeContractAsync({
        address: ROUTER, abi: ROUTER_ABI, functionName: "swapExactTokensForTokens",
        args: [parsed, 0n, routePath, address, deadline],
      });

      showToast("info", "Swap submitted…", hash);
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      if (receipt.status === "reverted") showToast("error", "Swap reverted on-chain", hash);
      else { showToast("success", `Swap ${tokenIn.symbol} → ${tokenOut.symbol} confirmed ✓`, hash); setLastTx(hash); setAmount(""); }
    } catch (err) {
      showToast("error", err?.shortMessage || err?.message || "Swap failed");
    } finally { setBusy(false); }
  }

  return (
    <>
      {toast && (
        <div className={`amphi-toast amphi-toast--${toast.kind}`}>
          <span>{toast.text}</span>
          {toast.hash && <a href={explorerTx(toast.hash)} target="_blank" rel="noreferrer">Tx <ExternalLink size={11} /></a>}
        </div>
      )}

      {oracleStale && <div className="amphi-card amphi-notice amphi-notice--warn amphi-notice-full">Oracle prices are updating, swaps paused.</div>}

      <div className="amphi-card amphi-card--mix amphi-notice-full">
        <div className="amphi-card-title">Swap Tokens</div>
        <div className="amphi-field">
          <select className="amphi-input" value={tokenIn.symbol} onChange={(e) => setTokenIn(safeTokenList.find(t => t.symbol === e.target.value))}>
            {safeTokenList.map((t) => <option key={t.symbol} value={t.symbol}>{t.symbol}</option>)}
          </select>
        </div>
        <div className="amphi-card-desc" style={{ marginTop: -6, marginBottom: 6 }}>
          Balance: <strong>{balanceIn != null ? balanceIn.toLocaleString(undefined, { maximumFractionDigits: 4 }) : "…"} {tokenIn.symbol}</strong>
        </div>
        <div className="amphi-field" style={{ display: "flex", gap: 6 }}>
          <input className="amphi-input" type="number" placeholder="0.00" value={amount} onChange={(e) => setAmount(e.target.value)} style={{ flex: 1 }} />
          <button className="amphi-btn-ghost" type="button" onClick={() => balanceIn != null && setAmount(String(balanceIn))} style={{ padding: "0 12px", borderRadius: 8, fontSize: 11 }}>
            Max
          </button>
        </div>
        <button className="amphi-btn amphi-btn-ghost" onClick={flip} type="button" style={{ marginTop: 8 }}>
          <ArrowUpDown size={13} /> Flip
        </button>
        <div className="amphi-field">
          <select className="amphi-input" value={tokenOut.symbol} onChange={(e) => setTokenOut(safeTokenList.find(t => t.symbol === e.target.value))}>
            {safeTokenList.map((t) => <option key={t.symbol} value={t.symbol}>{t.symbol}</option>)}
          </select>
        </div>
        <div className="amphi-card-desc" style={{ marginTop: -6, marginBottom: 6 }}>
          Balance: <strong>{balanceOut != null ? balanceOut.toLocaleString(undefined, { maximumFractionDigits: 4 }) : "…"} {tokenOut.symbol}</strong>
        </div>
        <div className="amphi-card-desc">Route: {routeDisplay}</div>
        
        {!isConnected ? <div className="amphi-notice">Connect your wallet to swap</div>
        : !isRightChain ? <div className="amphi-notice amphi-notice--warn">Wrong network — switch to GIWA Sepolia</div>
        : <button className="amphi-btn amphi-btn-crypto" onClick={runSwap} disabled={!canSwap}>
            {busy ? <><RefreshCw size={13} className="spinIcon" /> Processing…</> : `Swap ${tokenIn.symbol} → ${tokenOut.symbol}`}
          </button>}
        {lastTx && <div className="amphi-card-desc"><a href={explorerTx(lastTx)} target="_blank" rel="noreferrer">View last tx ↗</a></div>}
      </div>
    </>
  );
}

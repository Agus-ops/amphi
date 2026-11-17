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
  const { data: oracleStale, isError: oracleReadError, isRefetchError: oracleRefetchError } = useReadContract({ address: ORACLE, abi: ORACLE_ABI, functionName: "isStale" });
  // Fail-closed (temuan Mega/Xue Yi, 17 Nov 2026): status oracle yang belum terbaca
  // (undefined saat loading/error) TIDAK dianggap segar. Swap hanya boleh jalan
  // setelah isStale terbaca eksplisit `false`.
  const oracleUnknown = oracleStale === undefined;
  // Fail-closed lanjutan (validasi pascapatch Mega/Xue Yi): `data` wagmi adalah hasil
  // sukses TERAKHIR — bila refresh gagal, data lama `false` bisa menahan gerbang tetap
  // terbuka memakai status basi. Error/refetch-error ikut menutup gerbang.
  const oracleReadFailed = oracleReadError || oracleRefetchError;
  const oracleOk = oracleStale === false && !oracleReadFailed;

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
  const [quote, setQuote] = useState(null);
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

  const routePath = isDirectRoute || tokenIn.address === TOKENS.mUSDC || tokenOut.address === TOKENS.mUSDC
    ? [tokenIn.address, tokenOut.address]
    : [tokenIn.address, TOKENS.mUSDC, tokenOut.address];

  const routeDisplay = routePath.length === 2 ? `${tokenIn.symbol} → ${tokenOut.symbol}` : `${tokenIn.symbol} → mUSDC → ${tokenOut.symbol}`;
  const routePathKey = routePath.join(",");
  const quoteKey = `${amountNum}|${routePathKey}`;
  // Fail-closed: tanpa quote yang valid untuk input saat ini, swap TIDAK bisa jalan —
  // tidak ada lagi jalur amountOutMin = 0.
  const quoteValid = !!(quote && quote.key === quoteKey && quote.out > 0n);
  // Lantai minimum tidak boleh nol juga pada quote sangat kecil (floor(quote*99/100) bisa 0).
  const minOutFloor = quoteValid ? (quote.out * 99n) / 100n : 0n;
  const canSwap = isConnected && isRightChain && !busy && oracleOk && quoteValid && minOutFloor > 0n && amountNum > 0 && tokenIn.address !== tokenOut.address;

  // Live quote: estimated output from the router + price impact vs the pools' spot rate.
  useEffect(() => {
    setQuote(null);
    if (!publicClient || amountNum <= 0 || tokenIn.address === tokenOut.address) return;
    let cancelled = false;
    const timer = setTimeout(async () => {
      try {
        const parsed = parseUnits(String(amountNum), 18);
        const amounts = await publicClient.readContract({
          address: ROUTER, abi: ROUTER_ABI, functionName: "getAmountsOut", args: [parsed, routePath],
        });
        const out = amounts[amounts.length - 1];
        let spotOut = null;
        try {
          let spot = amountNum;
          for (let i = 0; i < routePath.length - 1; i++) {
            const pair = await publicClient.readContract({
              address: FACTORY, abi: FACTORY_ABI, functionName: "getPair", args: [routePath[i], routePath[i + 1]],
            });
            if (!pair || pair === "0x0000000000000000000000000000000000000000") { spot = null; break; }
            const [balIn, balOut] = await Promise.all([
              publicClient.readContract({ address: routePath[i], abi: ERC20_ABI, functionName: "balanceOf", args: [pair] }),
              publicClient.readContract({ address: routePath[i + 1], abi: ERC20_ABI, functionName: "balanceOf", args: [pair] }),
            ]);
            const rIn = Number(formatUnits(balIn, 18));
            const rOut = Number(formatUnits(balOut, 18));
            if (rIn <= 0 || rOut <= 0) { spot = null; break; }
            spot = spot * (rOut / rIn);
          }
          spotOut = spot;
        } catch { spotOut = null; }
        if (cancelled) return;
        const outNum = Number(formatUnits(out, 18));
        const impact = spotOut && spotOut > 0 ? Math.max(0, (1 - outNum / spotOut) * 100) : null;
        setQuote({ out, outNum, impact, key: quoteKey });
      } catch { if (!cancelled) setQuote(null); }
    }, 400);
    return () => { cancelled = true; clearTimeout(timer); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [publicClient, quoteKey]);

  async function runSwap() {
    if (!address || !publicClient || busy) return;
    if (tokenIn.address === tokenOut.address) { showToast("error", "Select different tokens"); return; }
    if (!quoteValid) { showToast("error", "No valid quote yet — swap blocked"); return; }
    if (!oracleOk) { showToast("error", "Oracle status not confirmed fresh — swap blocked"); return; }
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
      const minOut = minOutFloor; // quoteValid + minOutFloor > 0 sudah ditegakkan — fallback ke 0 dihapus.
      const hash = await writeContractAsync({
        address: ROUTER, abi: ROUTER_ABI, functionName: "swapExactTokensForTokens",
        args: [parsed, minOut, routePath, address, deadline],
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
      {oracleUnknown && !oracleReadFailed && <div className="amphi-card amphi-notice amphi-notice--warn amphi-notice-full">Checking oracle status, swaps paused until confirmed fresh.</div>}
      {oracleReadFailed && <div className="amphi-card amphi-notice amphi-notice--warn amphi-notice-full">Oracle status check failed, swaps paused.</div>}

      <div className="amphi-card amphi-card--mix amphi-notice-full">
        <div className="amphi-card-title">Swap Tokens</div>
        <div className="amphi-field">
          <select className="amphi-input" value={tokenIn.symbol} onChange={(e) => setTokenIn(safeTokenList.find(t => t.symbol === e.target.value))}>
            {safeTokenList.map((t) => <option key={t.symbol} value={t.symbol}>{t.symbol}</option>)}
          </select>
        </div>
        <div className="amphi-balance-line">
          Balance: <strong>{balanceIn != null ? balanceIn.toLocaleString(undefined, { maximumFractionDigits: 4 }) : "…"} {tokenIn.symbol}</strong>
        </div>
        <div className="amphi-field">
          <input className="amphi-input" type="number" placeholder="0.00" value={amount} onChange={(e) => setAmount(e.target.value)} />
          <button className="amphi-max-btn" type="button" onClick={() => balanceIn != null && setAmount(String(balanceIn))}>
            Max
          </button>
        </div>
        <div className="amphi-flip-row">
          <button className="amphi-flip-btn" onClick={flip} type="button" aria-label="Flip tokens">
            <ArrowUpDown size={15} />
          </button>
        </div>
        <div className="amphi-field">
          <select className="amphi-input" value={tokenOut.symbol} onChange={(e) => setTokenOut(safeTokenList.find(t => t.symbol === e.target.value))}>
            {safeTokenList.map((t) => <option key={t.symbol} value={t.symbol}>{t.symbol}</option>)}
          </select>
        </div>
        <div className="amphi-balance-line">
          Balance: <strong>{balanceOut != null ? balanceOut.toLocaleString(undefined, { maximumFractionDigits: 4 }) : "…"} {tokenOut.symbol}</strong>
        </div>
        <div className="amphi-card-desc" style={{ marginTop: 10 }}>Route: {routeDisplay}</div>
        {amountNum > 0 && tokenIn.address !== tokenOut.address && (
          quote && quote.key === quoteKey ? (
            <>
              <div className="amphi-quota-text" style={{ marginTop: 6 }}><span>You receive (est.):</span><span>{quote.outNum.toLocaleString(undefined, { maximumFractionDigits: 6 })} {tokenOut.symbol}</span></div>
              {quote.impact != null && <div className="amphi-quota-text"><span>Price impact (est.):</span><span style={quote.impact > 5 ? { color: "var(--bad)" } : undefined}>~{quote.impact.toFixed(2)}%</span></div>}
              <div className="amphi-quota-text"><span>Min. received (1% slippage):</span><span>{(quote.outNum * 0.99).toLocaleString(undefined, { maximumFractionDigits: 6 })} {tokenOut.symbol}</span></div>
            </>
          ) : (
            <div className="amphi-card-desc" style={{ marginTop: 6 }}>Fetching quote…</div>
          )
        )}
        
        {!isConnected ? <div className="amphi-notice">Connect your wallet to swap</div>
        : !isRightChain ? <div className="amphi-notice amphi-notice--warn">Wrong network — switch to GIWA Sepolia</div>
        : <button className="amphi-btn amphi-btn-crypto" onClick={runSwap} disabled={!canSwap}>
            {busy ? <><RefreshCw size={13} className="spinIcon" /> Processing…</> : `Swap ${tokenIn.symbol} → ${tokenOut.symbol}`}
          </button>}
        {lastTx && <div className="amphi-txlink"><a href={explorerTx(lastTx)} target="_blank" rel="noreferrer">View last tx ↗</a></div>}
      </div>
    </>
  );
}

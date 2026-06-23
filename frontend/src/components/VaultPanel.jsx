import { useEffect, useRef, useState } from "react";
import { useAccount, usePublicClient, useWriteContract } from "wagmi";
import { formatUnits, parseUnits } from "viem";
import { ExternalLink, Lock, RefreshCw, Unlock as UnlockIcon } from "lucide-react";
import { VAULTS, TOKENS, REWARD_POOLS } from "../contracts/contracts";
import { ERC20_ABI, VAULT_ABI, REWARD_POOL_ABI } from "../contracts/abis";
import { GIWA_SEPOLIA } from "../config/chains";

const DURATIONS = [
  { label: "7 days",  seconds: 7 * 86400,  weight: "1.0x" },
  { label: "15 days", seconds: 15 * 86400, weight: "1.5x" },
  { label: "30 days", seconds: 30 * 86400, weight: "2.0x" },
];

const VAULT_OPTS = [
  { id: "gold", name: "Gold", address: VAULTS.gold, token: TOKENS.mGold, rewardPool: REWARD_POOLS.gold },
  { id: "silver", name: "Silver", address: VAULTS.silver, token: TOKENS.mSilver, rewardPool: REWARD_POOLS.silver },
  { id: "platinum", name: "Platinum", address: VAULTS.platinum, token: TOKENS.mPlatinum, rewardPool: REWARD_POOLS.platinum },
];

export function VaultPanel({ isConnected, isRightChain }) {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { writeContractAsync } = useWriteContract();

  const [activeVault, setActiveVault] = useState(VAULT_OPTS[0]);
  const [amount, setAmount] = useState("");
  const [duration, setDuration] = useState(DURATIONS[1]);
  const [position, setPosition] = useState(null);
  const [pendingReward, setPendingReward] = useState(null);
  const [totalRewards, setTotalRewards] = useState(null);
  const [tokenBalance, setTokenBalance] = useState(null);
  
  const [busy, setBusy] = useState(false);
  const [toast, setToast] = useState(null);
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
    publicClient.readContract({ address: activeVault.rewardPool, abi: REWARD_POOL_ABI, functionName: "totalRewards" })
      .then((res) => { if (!cancelled) setTotalRewards(res); })
      .catch(() => {});
  }, [publicClient, activeVault]);

  useEffect(() => {
    if (!publicClient || !address) return;
    setTokenBalance(null);
    let cancelled = false;
    publicClient.readContract({ address: activeVault.token, abi: ERC20_ABI, functionName: "balanceOf", args: [address] })
      .then((res) => { if (!cancelled) setTokenBalance(res); })
      .catch(() => {});
    return () => { cancelled = true; };
  }, [publicClient, address, activeVault]);

  useEffect(() => {
    if (!publicClient || !address) return;
    setPosition(null);
    setPendingReward(null);
    let cancelled = false;
    publicClient.readContract({ address: activeVault.address, abi: VAULT_ABI, functionName: "positions", args: [address] })
      .then((res) => { if (!cancelled) setPosition({ amount: res[0], weight: res[1], unlockTime: Number(res[2]) }); })
      .catch(() => {});
    publicClient.readContract({ address: activeVault.address, abi: VAULT_ABI, functionName: "pendingReward", args: [address] })
      .then((res) => { if (!cancelled) setPendingReward(res); })
      .catch(() => {});
    const id = setInterval(() => {
      publicClient.readContract({ address: activeVault.address, abi: VAULT_ABI, functionName: "pendingReward", args: [address] })
        .then((res) => { if (!cancelled) setPendingReward(res); })
        .catch(() => {});
    }, 15000);
    return () => { cancelled = true; clearInterval(id); };
  }, [publicClient, address, activeVault]);

  const amountNum = parseFloat(String(amount).replace(",", ".")) || 0;
  const canLock = isConnected && isRightChain && !busy && amountNum > 0;
  const hasPosition = position && Number(position.amount) > 0;
  const isMature = hasPosition && Date.now() / 1000 >= position.unlockTime;

  async function runLock() {
    if (!address || !publicClient || busy) return;
    setBusy(true);
    try {
      const parsed = parseUnits(String(amountNum), 18);
      const allowance = await publicClient.readContract({
        address: activeVault.token, abi: ERC20_ABI, functionName: "allowance", args: [address, activeVault.address],
      });
      if (allowance < parsed) {
        showToast("info", `Approving m${activeVault.name}…`);
        const ah = await writeContractAsync({ address: activeVault.token, abi: ERC20_ABI, functionName: "approve", args: [activeVault.address, parsed] });
        await publicClient.waitForTransactionReceipt({ hash: ah });
      }
      const hash = await writeContractAsync({ address: activeVault.address, abi: VAULT_ABI, functionName: "lock", args: [parsed, BigInt(duration.seconds)] });
      showToast("info", `Locking m${activeVault.name}…`, hash);
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      if (receipt.status === "reverted") showToast("error", "Lock reverted", hash);
      else { showToast("success", `m${activeVault.name} locked ✓`, hash); setAmount(""); }
    } catch (err) {
      showToast("error", err?.shortMessage || err?.message || "Lock failed");
    } finally { setBusy(false); }
  }

  async function runClaimOrUnlock(fnName) {
    if (!address || !publicClient || busy) return;
    setBusy(true);
    try {
      const hash = await writeContractAsync({ address: activeVault.address, abi: VAULT_ABI, functionName: fnName });
      showToast("info", `${fnName === "unlock" ? "Unlocking" : "Claiming"}…`, hash);
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      if (receipt.status === "reverted") showToast("error", "Transaction reverted", hash);
      else showToast("success", fnName === "unlock" ? "Unlocked ✓" : "Reward claimed ✓", hash);
    } catch (err) {
      showToast("error", err?.shortMessage || err?.message || "Transaction failed");
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

      <div className="amphi-grid-full" style={{ display: "flex", gap: 8, marginBottom: 16 }}>
        {VAULT_OPTS.map((v) => (
          <button key={v.id} onClick={() => setActiveVault(v)} className="amphi-btn-ghost" style={{ flex: 1, padding: "8px", borderRadius: 8, background: activeVault.id === v.id ? "#1C1408" : "transparent", color: activeVault.id === v.id ? "#D9A85C" : "#8A8F9C", borderColor: activeVault.id === v.id ? "#7A6238" : "#1F2530" }}>
            {v.name}
          </button>
        ))}
      </div>

      <div className="amphi-card amphi-card--gold">
        <div className="amphi-card-title"><span><Lock size={13} /> Lock m{activeVault.name}</span></div>
        <div className="amphi-card-desc">Pool total rewards: <strong>{totalRewards != null ? `${formatUnits(totalRewards, 18)} ETH` : "…"}</strong></div>
        <div style={{ display: "flex", gap: 6, marginTop: 8 }}>
          {DURATIONS.map((d) => (
            <button key={d.label} type="button" onClick={() => setDuration(d)}
              className="amphi-btn-ghost" style={{
                flex: 1, padding: "8px 4px", fontSize: 11, borderRadius: 10,
                borderColor: duration.label === d.label ? "#7A6238" : "#1F2530",
                color: duration.label === d.label ? "#D9A85C" : "#8A8F9C",
                background: duration.label === d.label ? "#1C1408" : "transparent",
              }}>
              {d.label}<br /><span style={{ fontSize: 9.5 }}>{d.weight}</span>
            </button>
          ))}
        </div>
        <div className="amphi-card-desc" style={{ marginTop: 8 }}>
          Available: <strong>{tokenBalance != null ? Number(formatUnits(tokenBalance, 18)).toLocaleString(undefined, { maximumFractionDigits: 4 }) : "…"} m{activeVault.name}</strong>
        </div>
        <div className="amphi-field" style={{ display: "flex", gap: 6 }}>
          <input className="amphi-input" type="number" placeholder={`0.00 m${activeVault.name}`} value={amount} onChange={(e) => setAmount(e.target.value)} style={{ flex: 1 }} />
          <button className="amphi-btn-ghost" type="button" onClick={() => tokenBalance != null && setAmount(formatUnits(tokenBalance, 18))} style={{ padding: "0 12px", borderRadius: 8, fontSize: 11 }}>
            Max
          </button>
        </div>
        {!isConnected ? <div className="amphi-notice">Connect wallet to lock</div>
        : !isRightChain ? <div className="amphi-notice amphi-notice--warn">Wrong network</div>
        : <button className="amphi-btn amphi-btn-gold" onClick={runLock} disabled={!canLock}>
            {busy ? <><RefreshCw size={13} className="spinIcon" /> Processing…</> : `Lock m${activeVault.name}`}
          </button>}
      </div>

      <div className="amphi-card amphi-card--gold">
        <div className="amphi-card-title">Your {activeVault.name} Position</div>
        {!hasPosition ? (
          <div className="amphi-card-desc">No active position yet.</div>
        ) : (
          <>
            <div className="amphi-card-desc">
              Locked: <strong>{formatUnits(position.amount, 18)} m{activeVault.name}</strong><br />
              {isMature ? "Unlocked — ready to withdraw" : `Unlocks ${new Date(position.unlockTime * 1000).toLocaleString()}`}<br />
              Pending reward: <strong>{pendingReward != null ? `${formatUnits(pendingReward, 18)} ETH` : "…"}</strong>
            </div>
            <button className="amphi-btn amphi-btn-ghost" onClick={() => runClaimOrUnlock("claimReward")} disabled={busy || !pendingReward || pendingReward === 0n}>
              Claim Reward {pendingReward != null && pendingReward > 0n ? `(${formatUnits(pendingReward, 18)} ETH)` : ""}
            </button>
            <button className="amphi-btn amphi-btn-ghost" onClick={() => runClaimOrUnlock("unlock")} disabled={busy || !isMature}>
              <UnlockIcon size={13} /> Unlock
            </button>
          </>
        )}
      </div>
    </>
  );
}

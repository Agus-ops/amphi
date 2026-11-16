import { Fragment, useState, useEffect } from "react";
import { useAccount, useBalance, useReadContracts } from "wagmi";
import { formatUnits } from "viem";
import { User, Copy, ExternalLink, Activity } from "lucide-react";
import { TOKENS, VAULTS, POOLS } from "../contracts/contracts";
import { ERC20_ABI, VAULT_ABI } from "../contracts/abis";
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

const VAULT_LIST = [
  { id: "gold", name: "Gold", address: VAULTS.gold },
  { id: "silver", name: "Silver", address: VAULTS.silver },
  { id: "platinum", name: "Platinum", address: VAULTS.platinum },
];

const POOL_LIST = [
  { id: "USDC_BTC", label: "USDC–BTC", address: POOLS.USDC_BTC },
  { id: "USDC_ETH", label: "USDC–ETH", address: POOLS.USDC_ETH },
  { id: "USDC_SOL", label: "USDC–SOL", address: POOLS.USDC_SOL },
  { id: "USDC_Gold", label: "USDC–Gold", address: POOLS.USDC_Gold },
  { id: "USDC_Silver", label: "USDC–Silver", address: POOLS.USDC_Silver },
  { id: "USDC_Platinum", label: "USDC–Platinum", address: POOLS.USDC_Platinum },
];

function fmtCountdown(unlockTime, nowSec) {
  const diff = unlockTime - nowSec;
  if (diff <= 0) return "Ready to unlock";
  const d = Math.floor(diff / 86400);
  const h = Math.floor((diff % 86400) / 3600);
  const m = Math.floor((diff % 3600) / 60);
  if (d > 0) return `Unlocks in ${d}d ${h}h`;
  if (h > 0) return `Unlocks in ${h}h ${m}m`;
  return `Unlocks in ${m}m`;
}

function getGreeting() {
  const h = new Date().getHours();
  if (h < 5) return "Burning the midnight oil";
  if (h < 11) return "Good morning";
  if (h < 15) return "Good afternoon";
  if (h < 19) return "Good evening";
  return "Good night";
}

function fmtAmt(v, dp = 4) {
  if (!Number.isFinite(v)) return "0";
  return new Intl.NumberFormat(undefined, { maximumFractionDigits: dp }).format(v);
}

export function ProfilePanel({ isConnected, isRightChain }) {
  const { address } = useAccount();
  const { data: ethBalance } = useBalance({ address });

  const [copied, setCopied] = useState(false);
  const [stats, setStats] = useState(null);
  const [statsLoading, setStatsLoading] = useState(false);
  const [nowSec, setNowSec] = useState(() => Math.floor(Date.now() / 1000));

  useEffect(() => {
    const id = setInterval(() => setNowSec(Math.floor(Date.now() / 1000)), 30000);
    return () => clearInterval(id);
  }, []);

  const explorerAddr = (addr) => `${GIWA_SEPOLIA.explorerUrl}/address/${addr}`;

  function copyAddress() {
    if (!address) return;
    navigator.clipboard.writeText(address).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  }

  const { data: balanceData } = useReadContracts({
    contracts: TOKEN_LIST.map((t) => ({
      address: t.address,
      abi: ERC20_ABI,
      functionName: "balanceOf",
      args: [address],
    })),
    query: { enabled: !!address },
  });

  const { data: positionData } = useReadContracts({
    contracts: VAULT_LIST.map((v) => ({
      address: v.address,
      abi: VAULT_ABI,
      functionName: "positions",
      args: [address],
    })),
    query: { enabled: !!address },
  });

  const { data: rewardData } = useReadContracts({
    contracts: VAULT_LIST.map((v) => ({
      address: v.address,
      abi: VAULT_ABI,
      functionName: "pendingReward",
      args: [address],
    })),
    query: { enabled: !!address },
  });

  const { data: lpData } = useReadContracts({
    contracts: POOL_LIST.map((p) => ({
      address: p.address,
      abi: ERC20_ABI,
      functionName: "balanceOf",
      args: [address],
    })),
    query: { enabled: !!address },
  });

  useEffect(() => {
    if (!address) return;
    let cancelled = false;
    setStatsLoading(true);
    fetch(`${GIWA_SEPOLIA.explorerUrl}/api/v2/addresses/${address}/counters`)
      .then((res) => res.json())
      .then((json) => { if (!cancelled) setStats(json); })
      .catch(() => {})
      .finally(() => { if (!cancelled) setStatsLoading(false); });
    return () => { cancelled = true; };
  }, [address]);

  if (!isConnected) {
    return <div className="amphi-card amphi-notice-full"><div className="amphi-notice">Connect your wallet to view your profile</div></div>;
  }

  const tokenBalances = TOKEN_LIST.map((t, i) => ({
    symbol: t.symbol,
    amount: balanceData?.[i]?.result != null ? Number(formatUnits(balanceData[i].result, 18)) : null,
  }));

  const vaultPositions = VAULT_LIST.map((v, i) => {
    const res = positionData?.[i]?.result;
    const amount = res ? Number(formatUnits(res[0], 18)) : 0;
    const unlockTime = res ? Number(res[2]) : 0;
    const rewardRes = rewardData?.[i]?.result;
    const pendingReward = rewardRes != null ? Number(formatUnits(rewardRes, 18)) : null;
    return { ...v, amount, unlockTime, pendingReward, hasPosition: amount > 0 };
  });

  const activePositions = vaultPositions.filter((v) => v.hasPosition);

  const lpPositions = POOL_LIST.map((p, i) => ({
    ...p,
    amount: lpData?.[i]?.result != null ? Number(formatUnits(lpData[i].result, 18)) : 0,
  }));
  const activeLps = lpPositions.filter((p) => p.amount > 0);

  return (
    <>
      <div className="amphi-card amphi-card--mix">
        <div className="amphi-card-title"><span><User size={13} /> {getGreeting()}</span></div>
        <div className="amphi-card-desc" style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 6 }}>
          <span>{address?.slice(0, 10)}…{address?.slice(-8)}</span>
          <button className="amphi-copy-btn" onClick={copyAddress} type="button">
            <Copy size={11} /> {copied ? "Copied" : "Copy"}
          </button>
          <a href={explorerAddr(address)} target="_blank" rel="noreferrer" style={{ fontSize: 10 }}>
            <ExternalLink size={11} />
          </a>
        </div>
        {!isRightChain && <div className="amphi-notice amphi-notice--warn" style={{ marginTop: 8 }}>Wrong network — switch to GIWA Sepolia</div>}
      </div>

      <div className="amphi-card amphi-card--crypto">
        <div className="amphi-card-title"><span>Balances</span></div>
        <div style={{ marginTop: 10 }}>
          <div className="amphi-row"><span className="amphi-row-label">ETH</span><span className="amphi-row-value">{ethBalance ? fmtAmt(Number(formatUnits(ethBalance.value, 18))) : "…"}</span></div>
          {tokenBalances.map((t) => (
            <div className="amphi-row" key={t.symbol}><span className="amphi-row-label">{t.symbol}</span><span className="amphi-row-value">{t.amount != null ? fmtAmt(t.amount, 2) : "…"}</span></div>
          ))}
        </div>
      </div>

      <div className="amphi-card amphi-card--gold">
        <div className="amphi-card-title"><span>Vault Positions</span></div>
        {activePositions.length === 0 ? (
          <div className="amphi-card-desc">No active vault positions yet.</div>
        ) : (
          <div style={{ marginTop: 10 }}>
            {activePositions.map((v) => (
              <Fragment key={v.id}>
                <div className="amphi-row"><span className="amphi-row-label">{v.name}</span><span className="amphi-row-value">{fmtAmt(v.amount, 4)} m{v.name} locked</span></div>
                <div className="amphi-row"><span className="amphi-row-label">Maturity</span><span className="amphi-row-value">{v.unlockTime ? `${fmtCountdown(v.unlockTime, nowSec)} · ${new Date(v.unlockTime * 1000).toLocaleDateString()}` : "—"}</span></div>
                {v.pendingReward != null && v.pendingReward > 0 && (
                  <div className="amphi-row"><span className="amphi-row-label">Pending reward</span><span className="amphi-row-value">{fmtAmt(v.pendingReward, 6)} ETH</span></div>
                )}
              </Fragment>
            ))}
          </div>
        )}
      </div>

      <div className="amphi-card amphi-card--crypto">
        <div className="amphi-card-title"><span>Liquidity Positions</span></div>
        {activeLps.length === 0 ? (
          <div className="amphi-card-desc">No liquidity positions yet.</div>
        ) : (
          <div style={{ marginTop: 10 }}>
            {activeLps.map((p) => (
              <div className="amphi-row" key={p.id}><span className="amphi-row-label">{p.label}</span><span className="amphi-row-value">{fmtAmt(p.amount, 6)} LP</span></div>
            ))}
          </div>
        )}
      </div>

      <div className="amphi-card amphi-card--mix">
        <div className="amphi-card-title"><span><Activity size={13} /> Activity</span></div>
        <div style={{ marginTop: 10 }}>
          {statsLoading ? <div className="amphi-card-desc">Loading…</div> : !stats ? <div className="amphi-card-desc">Could not load activity data.</div> : (
            <>
              <div className="amphi-row"><span className="amphi-row-label">Total transactions</span><span className="amphi-row-value">{stats.transactions_count ?? "—"}</span></div>
              <div className="amphi-row"><span className="amphi-row-label">Token transfers</span><span className="amphi-row-value">{stats.token_transfers_count ?? "—"}</span></div>
            </>
          )}
        </div>
        <a href={explorerAddr(address)} target="_blank" rel="noreferrer" className="amphi-card-desc" style={{ display: "block", marginTop: 8 }}>
          View full history on explorer ↗
        </a>
      </div>
    </>
  );
}

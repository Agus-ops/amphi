import { useState, useRef } from "react";
import { useAccount, usePublicClient, useWriteContract } from "wagmi";
import { parseEther, isAddress } from "viem";
import { ExternalLink, RefreshCw, ShieldCheck } from "lucide-react";
import { MULTISIG } from "../contracts/contracts";
import { GIWA_SEPOLIA } from "../config/chains";

// ABI minimal untuk Multisig Panel
const MULTISIG_ABI = [
  { type: 'function', name: 'getTransaction', inputs: [{ name: 'txId', type: 'uint256' }], outputs: [{ name: 'to', type: 'address' }, { name: 'value', type: 'uint256' }, { name: 'data', type: 'bytes' }, { name: 'executed', type: 'bool' }, { name: 'confirmations', type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'confirmTransaction', inputs: [{ name: 'txId', type: 'uint256' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'executeTransaction', inputs: [{ name: 'txId', type: 'uint256' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'submitTransaction', inputs: [{ name: 'to', type: 'address' }, { name: 'value', type: 'uint256' }, { name: 'data', type: 'bytes' }], outputs: [{ name: 'txId', type: 'uint256' }], stateMutability: 'nonpayable' },
  { type: 'function', name: 'getTransactionCount', inputs: [], outputs: [{ name: '', type: 'uint256' }], stateMutability: 'view' },
  { type: 'function', name: 'revokeConfirmation', inputs: [{ name: 'txId', type: 'uint256' }], outputs: [], stateMutability: 'nonpayable' },
  { type: 'function', name: 'isConfirmedBy', inputs: [{ name: 'txId', type: 'uint256' }, { name: 'owner', type: 'address' }], outputs: [{ name: '', type: 'bool' }], stateMutability: 'view' }
];

export function AdminPanel({ isConnected, isRightChain }) {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { writeContractAsync } = useWriteContract();

  const [txId, setTxId] = useState("");
  const [txInfo, setTxInfo] = useState(null);
  const [busy, setBusy] = useState(false);

  const [submitTo, setSubmitTo] = useState("");
  const [submitValue, setSubmitValue] = useState("");
  const [submitData, setSubmitData] = useState("");
  const [busySubmit, setBusySubmit] = useState(false);
  const [toast, setToast] = useState(null);
  const toastTimer = useRef(null);

  const explorerTx = (hash) => `${GIWA_SEPOLIA.explorerUrl}/tx/${hash}`;

  function showToast(kind, text, hash = null) {
    setToast({ kind, text, hash });
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 8000);
  }

  async function lookupTx() {
    if (!publicClient || txId === "") return;
    try {
      const res = await publicClient.readContract({ address: MULTISIG, abi: MULTISIG_ABI, functionName: "getTransaction", args: [BigInt(txId)] });
      let confirmedByMe = false;
      if (address) {
        try {
          confirmedByMe = await publicClient.readContract({ address: MULTISIG, abi: MULTISIG_ABI, functionName: "isConfirmedBy", args: [BigInt(txId), address] });
        } catch {}
      }
      setTxInfo({ to: res[0], value: res[1], executed: res[3], confirmations: res[4], confirmedByMe });
    } catch {
      showToast("error", "Could not load transaction — check the Tx ID");
    }
  }

  async function runSubmit() {
    if (!address || !publicClient || busySubmit) return;
    if (!isAddress(submitTo)) { showToast("error", "Invalid recipient address"); return; }

    setBusySubmit(true);
    try {
      const valueWei = submitValue ? parseEther(String(submitValue)) : 0n;
      const dataBytes = submitData && submitData.trim() !== "" ? submitData.trim() : "0x";

      const hash = await writeContractAsync({
        address: MULTISIG,
        abi: MULTISIG_ABI,
        functionName: "submitTransaction",
        args: [submitTo, valueWei, dataBytes],
      });
      showToast("info", "Submitting proposal…", hash);
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      if (receipt.status === "reverted") showToast("error", "Submit reverted", hash);
      else {
        showToast("success", "Proposal submitted ✓", hash);
        setSubmitTo(""); setSubmitValue(""); setSubmitData("");
        try {
          const count = await publicClient.readContract({ address: MULTISIG, abi: MULTISIG_ABI, functionName: "getTransactionCount" });
          if (count > 0n) setTxId(String(count - 1n));
        } catch {}
      }
    } catch (err) {
      showToast("error", err?.shortMessage || err?.message || "Submit failed");
    } finally { setBusySubmit(false); }
  }

  async function runAction(fnName) {
    if (!address || !publicClient || busy || txId === "") return;
    setBusy(true);
    try {
      const hash = await writeContractAsync({ address: MULTISIG, abi: MULTISIG_ABI, functionName: fnName, args: [BigInt(txId)] });
      showToast("info", `${fnName === "executeTransaction" ? "Executing" : "Confirming"}…`, hash);
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      if (receipt.status === "reverted") showToast("error", "Transaction reverted", hash);
      else { showToast("success", "Done ✓", hash); lookupTx(); }
    } catch (err) {
      showToast("error", err?.shortMessage || err?.message || "Action failed");
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

      <div className="amphi-card amphi-card--mix amphi-notice-full">
        <div className="amphi-card-title"><span><ShieldCheck size={13} /> Multisig Governance</span></div>
        <div className="amphi-card-desc">Multisig: {MULTISIG.slice(0, 8)}…{MULTISIG.slice(-6)}</div>

        {!isConnected ? <div className="amphi-notice">Connect your wallet to manage transactions</div>
        : !isRightChain ? <div className="amphi-notice amphi-notice--warn">Wrong network — switch to GIWA Sepolia</div>
        : (
          <>
            <div className="amphi-card" style={{ marginBottom: 16 }}>
              <div className="amphi-card-title"><span>Submit New Proposal</span></div>
              <div className="amphi-field">
                <input className="amphi-input" type="text" placeholder="To address (0x...)" value={submitTo} onChange={(e) => setSubmitTo(e.target.value)} />
              </div>
              <div className="amphi-field">
                <input className="amphi-input" type="number" placeholder="Value (ETH, optional)" value={submitValue} onChange={(e) => setSubmitValue(e.target.value)} />
              </div>
              <div className="amphi-field">
                <input className="amphi-input" type="text" placeholder="Calldata (0x..., optional)" value={submitData} onChange={(e) => setSubmitData(e.target.value)} />
              </div>
              <button className="amphi-btn amphi-btn-gold" onClick={runSubmit} disabled={busySubmit || submitTo === ""}>
                {busySubmit ? <><RefreshCw size={13} className="spinIcon" /> Submitting…</> : "Submit Proposal"}
              </button>
            </div>

            <div className="amphi-field">
              <input className="amphi-input" type="number" placeholder="Transaction ID" value={txId} onChange={(e) => setTxId(e.target.value)} />
            </div>
            <button className="amphi-btn amphi-btn-ghost" onClick={lookupTx} type="button">Look up</button>

            {txInfo && (
              <div className="amphi-card-desc" style={{ marginTop: 10 }}>
                To: {txInfo.to.slice(0, 8)}…{txInfo.to.slice(-6)}<br />
                Confirmations: {String(txInfo.confirmations)}<br />
                Status: {txInfo.executed ? "Executed" : "Pending"}<br />
                Confirmed by you: {txInfo.confirmedByMe ? "Yes" : "No"}
              </div>
            )}

            <button className="amphi-btn amphi-btn-crypto" onClick={() => runAction("confirmTransaction")} disabled={busy || txId === "" || txInfo?.confirmedByMe}>
              {busy ? <><RefreshCw size={13} className="spinIcon" /> Processing…</> : "Confirm"}
            </button>
            <button className="amphi-btn amphi-btn-ghost" onClick={() => runAction("revokeConfirmation")} disabled={busy || txId === "" || !txInfo?.confirmedByMe || txInfo?.executed}>
              Revoke Confirmation
            </button>
            <button className="amphi-btn amphi-btn-gold" onClick={() => runAction("executeTransaction")} disabled={busy || txId === "" || txInfo?.executed}>
              Execute
            </button>
          </>
        )}
      </div>
    </>
  );
}

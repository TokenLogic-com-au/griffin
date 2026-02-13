"use client";

import { useAccount } from "wagmi";
import { useFaucet } from "@/hooks/useFaucet";
import { targetChain } from "@/config/chains";
import type { FaucetToken } from "@/lib/faucet";

const TOKEN_BUTTONS: { token: FaucetToken | "all"; label: string; amount: string }[] = [
  { token: "all", label: "Drip All Tokens", amount: "ETH + USDC + USDT + GHO" },
  { token: "ETH", label: "ETH", amount: "100 ETH" },
  { token: "USDC", label: "USDC", amount: "100k" },
  { token: "USDT", label: "USDT", amount: "100k" },
  { token: "GHO", label: "GHO", amount: "100k" },
];

/**
 * Dev-only faucet panel for Anvil fork.
 */
export function FaucetPanel() {
  const { isConnected } = useAccount();
  const { drip, status, results, currentToken, reset } = useFaucet();

  if (targetChain.id !== 31337) return null;
  if (!isConnected) return null;

  const isDripping = status === "dripping";

  return (
    <div className="rounded-lg border border-dashed border-[var(--warning)]/30 bg-[var(--bg-secondary)] p-5">
      <div className="mb-3 flex items-center gap-2">
        <div className="flex h-6 w-6 items-center justify-center rounded-full bg-[var(--warning)]/15 text-xs">
          <svg className="h-3.5 w-3.5 text-[var(--warning)]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
          </svg>
        </div>
        <h3 className="text-sm font-semibold text-[var(--warning)]">Local Faucet</h3>
        <span className="rounded bg-[var(--warning)]/10 px-1.5 py-0.5 text-[9px] font-bold uppercase tracking-wider text-[var(--warning)]">
          Dev
        </span>
      </div>

      <p className="mb-4 text-xs text-[var(--text-muted)]">
        Drip test tokens via Anvil impersonation (mainnet fork required).
      </p>

      <div className="space-y-1.5">
        {TOKEN_BUTTONS.map(({ token, label, amount }) => (
          <button
            key={token}
            onClick={() => drip(token)}
            disabled={isDripping}
            className={`flex w-full items-center justify-between rounded-md px-3 py-2 text-sm transition-colors disabled:cursor-wait disabled:opacity-50 ${
              token === "all"
                ? "bg-[var(--warning)]/10 font-semibold text-[var(--warning)] hover:bg-[var(--warning)]/15"
                : "bg-[var(--bg-surface)] text-[var(--text-secondary)] hover:bg-[var(--bg-hover)] hover:text-[var(--text-primary)]"
            }`}
          >
            <span>
              {isDripping && currentToken === token ? (
                <span className="inline-flex items-center gap-1.5">
                  <svg className="h-3 w-3 animate-spin" viewBox="0 0 24 24" fill="none">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  Dripping...
                </span>
              ) : (
                label
              )}
            </span>
            <span className="text-xs text-[var(--text-muted)]">{amount}</span>
          </button>
        ))}
      </div>

      {results.length > 0 && (
        <div className="mt-3 space-y-1">
          {results.map((r, i) => (
            <div
              key={i}
              className={`flex items-center justify-between rounded px-2.5 py-1 text-xs ${
                r.success ? "bg-[var(--success)]/8 text-[var(--success)]" : "bg-[var(--error)]/8 text-[var(--error)]"
              }`}
            >
              <span className="font-medium">{r.success ? "OK" : "FAIL"} {r.token}</span>
              {r.error && <span className="max-w-[140px] truncate text-[10px] opacity-60" title={r.error}>{r.error}</span>}
            </div>
          ))}
          <button
            onClick={reset}
            className="mt-1 w-full rounded px-2 py-1 text-xs text-[var(--text-muted)] hover:text-[var(--text-secondary)]"
          >
            Dismiss
          </button>
        </div>
      )}
    </div>
  );
}

"use client";

import { useTokenBalances } from "@/hooks/useTokenBalances";
import { formatTokenAmount } from "@/lib/formatting";
import { TOKENS } from "@/config/tokens";
import { TokenIcon } from "./TokenSelector";

/**
 * Aave-style "Your info" sidebar showing wallet balances.
 */
export function BalanceDisplay() {
  const { balances, isLoading } = useTokenBalances();

  const items = [
    { symbol: "sGHO", label: "sGHO Shares", balance: balances.sGHO, decimals: 18, primary: true },
    { symbol: "GHO", label: "GHO", balance: balances.GHO, decimals: TOKENS.GHO.decimals },
    { symbol: "USDC", label: "USDC", balance: balances.USDC, decimals: TOKENS.USDC.decimals },
    { symbol: "USDT", label: "USDT", balance: balances.USDT, decimals: TOKENS.USDT.decimals },
  ];

  return (
    <div className="card">
      <h3 className="mb-5 text-sm font-semibold text-[var(--text-muted)]">Your info</h3>
      <div className="space-y-4">
        {items.map((item) => (
          <div key={item.symbol} className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <TokenIcon symbol={item.symbol} size="md" />
              <span className="text-sm font-medium text-[var(--text-secondary)]">{item.label}</span>
            </div>
            <span
              className={`text-sm tabular-nums ${
                item.primary ? "font-semibold text-[var(--text-primary)]" : "text-[var(--text-secondary)]"
              }`}
            >
              {isLoading ? (
                <span className="inline-block h-4 w-16 animate-pulse rounded bg-[var(--bg-hover)]" />
              ) : (
                formatTokenAmount(item.balance, item.decimals)
              )}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useAccount } from "wagmi";

import { ConnectWallet } from "@/components/ConnectWallet";
import { NetworkGuard } from "@/components/NetworkGuard";
import { TokenIcon } from "@/components/TokenSelector";
import { useMounted } from "@/hooks/useMounted";
import { useTokenBalances } from "@/hooks/useTokenBalances";
import { formatAddress, formatTokenAmount } from "@/lib/formatting";
import { TOKENS } from "@/config/tokens";

const CURRENT_APY_PERCENT = 5.37;

const HOLDINGS = [
  { symbol: "sGHO", label: "sGHO Shares", decimals: 18 },
  { symbol: "GHO", label: "GHO", decimals: TOKENS.GHO.decimals },
  { symbol: "USDC", label: "USDC", decimals: TOKENS.USDC.decimals },
  { symbol: "USDT", label: "USDT", decimals: TOKENS.USDT.decimals },
] as const;

function normalizeTo18(amount: bigint, decimals: number): bigint {
  if (decimals === 18) return amount;
  if (decimals < 18) return amount * 10n ** BigInt(18 - decimals);
  return amount / 10n ** BigInt(decimals - 18);
}

function formatUsd(value: number): string {
  if (!Number.isFinite(value)) return "$0.00";
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(value);
}

export default function DashboardPage() {
  const { address, isConnected } = useAccount();
  const [simulationPrincipalInput, setSimulationPrincipalInput] = useState("");
  const mounted = useMounted();
  const connected = mounted && isConnected;
  const { balances, isLoading } = useTokenBalances();

  const totalEstimatedUsd = useMemo(
    () =>
      HOLDINGS.reduce((sum, asset) => {
        const balance = balances[asset.symbol];
        return sum + normalizeTo18(balance, asset.decimals);
      }, 0n),
    [balances]
  );

  const totalEstimatedUsdFloat = useMemo(() => {
    const raw = formatTokenAmount(totalEstimatedUsd, 18, 8).replace(/,/g, "").replace("<", "");
    const parsed = Number(raw);
    return Number.isFinite(parsed) ? parsed : 0;
  }, [totalEstimatedUsd]);

  const simulationPrincipalUsd = useMemo(() => {
    if (!simulationPrincipalInput.trim()) return totalEstimatedUsdFloat;
    const parsed = Number(simulationPrincipalInput);
    if (!Number.isFinite(parsed) || parsed < 0) return 0;
    return parsed;
  }, [simulationPrincipalInput, totalEstimatedUsdFloat]);

  const projectedYearlyEarnings = useMemo(
    () => (simulationPrincipalUsd * CURRENT_APY_PERCENT) / 100,
    [simulationPrincipalUsd]
  );
  const projectedMonthlyEarnings = projectedYearlyEarnings / 12;
  const projectedDailyEarnings = projectedYearlyEarnings / 365;

  return (
    <NetworkGuard>
      <div className="flex min-h-screen flex-col">
        <nav className="border-b border-[var(--border-secondary)]">
          <div className="mx-auto flex h-14 max-w-[1200px] items-center justify-between px-4 sm:px-6">
            <div className="flex items-center gap-3">
              <h1 className="text-sm font-semibold text-[var(--text-primary)]">Dashboard</h1>
              <Link
                href="/"
                className="rounded-md border border-[var(--border-primary)] bg-[var(--bg-surface)] px-3 py-1.5 text-xs font-medium text-[var(--text-muted)] transition-colors hover:text-[var(--text-secondary)]"
              >
                Back to Router
              </Link>
            </div>
            <ConnectWallet />
          </div>
        </nav>

        <main className="mx-auto w-full max-w-[1200px] flex-1 px-4 py-8 sm:px-6">
          <div className="mb-6">
            <h2 className="text-3xl font-bold text-[var(--text-primary)]">Current holdings</h2>
            <p className="mt-2 text-sm text-[var(--text-secondary)]">
              Track your wallet balances across all supported assets.
            </p>
          </div>

          {!connected ? (
            <div className="card max-w-md text-center">
              <p className="mb-4 text-sm text-[var(--text-secondary)]">
                Connect your wallet to view holdings.
              </p>
              <ConnectWallet />
            </div>
          ) : (
            <div className="space-y-6">
              <div className="grid gap-4 md:grid-cols-3">
                <div className="card">
                  <p className="stat-label">Estimated Total Value</p>
                  <p className="stat-value mt-1">
                    {isLoading ? (
                      <span className="inline-block h-6 w-40 animate-pulse rounded bg-[var(--bg-hover)]" />
                    ) : (
                      <>${formatTokenAmount(totalEstimatedUsd, 18, 2)}</>
                    )}
                  </p>
                  <p className="mt-2 text-xs text-[var(--text-muted)]">
                    Assumes 1:1 value for GHO, USDC, USDT, and sGHO.
                  </p>
                </div>

                <div className="card">
                  <p className="stat-label">Current APY</p>
                  <p className="stat-value mt-1">{CURRENT_APY_PERCENT.toFixed(2)}%</p>
                  <p className="mt-2 text-xs text-[var(--text-muted)]">
                    Applied to projected earnings below.
                  </p>
                </div>

                <div className="card">
                  <p className="stat-label">Connected Wallet</p>
                  <p className="mt-1 font-mono text-sm text-[var(--text-primary)]">
                    {address ? formatAddress(address) : "-"}
                  </p>
                </div>
              </div>

              <div className="card">
                <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
                  <h3 className="text-lg font-semibold text-[var(--text-primary)]">Revenue simulation</h3>
                  <span className="rounded-md bg-[var(--aave-teal)]/15 px-2.5 py-1 text-xs font-semibold text-[var(--aave-teal)]">
                    {CURRENT_APY_PERCENT.toFixed(2)}% APY
                  </span>
                </div>
                <p className="text-sm text-[var(--text-secondary)]">
                  Projected earnings based on your principal amount and the current APY.
                </p>

                <div className="mt-5 grid gap-4 md:grid-cols-2">
                  <div>
                    <label className="text-xs font-medium text-[var(--text-muted)]">
                      Principal amount (USD)
                    </label>
                    <div className="input-box mt-2">
                      <span className="mr-2 text-sm text-[var(--text-muted)]">$</span>
                      <input
                        type="text"
                        inputMode="decimal"
                        value={simulationPrincipalInput}
                        onChange={(e) => {
                          const value = e.target.value;
                          if (value === "" || /^\d*\.?\d*$/.test(value)) {
                            setSimulationPrincipalInput(value);
                          }
                        }}
                        placeholder={formatTokenAmount(totalEstimatedUsd, 18, 2)}
                        className="w-full border-0 bg-transparent text-base font-semibold text-[var(--text-primary)] outline-none placeholder-[var(--text-muted)]"
                      />
                    </div>
                    <p className="mt-2 text-xs text-[var(--text-muted)]">
                      Leave blank to use your estimated total holdings value.
                    </p>
                  </div>

                  <div className="rounded-lg border border-[var(--border-secondary)] bg-[var(--bg-surface)] p-4">
                    <p className="text-xs font-medium text-[var(--text-muted)]">Projected yearly earnings</p>
                    <p className="mt-1 text-2xl font-bold text-[var(--text-primary)]">
                      {formatUsd(projectedYearlyEarnings)}
                    </p>
                    <div className="mt-4 space-y-2 text-xs text-[var(--text-secondary)]">
                      <div className="flex items-center justify-between">
                        <span>Monthly projection</span>
                        <span className="font-semibold text-[var(--text-primary)]">
                          {formatUsd(projectedMonthlyEarnings)}
                        </span>
                      </div>
                      <div className="flex items-center justify-between">
                        <span>Daily projection</span>
                        <span className="font-semibold text-[var(--text-primary)]">
                          {formatUsd(projectedDailyEarnings)}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div className="card">
                <h3 className="mb-4 text-lg font-semibold text-[var(--text-primary)]">Asset balances</h3>
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead>
                      <tr className="border-b border-[var(--border-secondary)]">
                        <th className="pb-3 text-left text-xs font-medium text-[var(--text-muted)]">Asset</th>
                        <th className="pb-3 text-right text-xs font-medium text-[var(--text-muted)]">Balance</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-[var(--border-secondary)]">
                      {HOLDINGS.map((asset) => (
                        <tr key={asset.symbol}>
                          <td className="py-4">
                            <div className="flex items-center gap-3">
                              <TokenIcon symbol={asset.symbol} size="md" />
                              <span className="text-sm font-semibold text-[var(--text-primary)]">
                                {asset.label}
                              </span>
                            </div>
                          </td>
                          <td className="py-4 text-right text-sm tabular-nums text-[var(--text-secondary)]">
                            {isLoading ? (
                              <span className="inline-block h-4 w-16 animate-pulse rounded bg-[var(--bg-hover)]" />
                            ) : (
                              formatTokenAmount(balances[asset.symbol], asset.decimals)
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}
        </main>
      </div>
    </NetworkGuard>
  );
}

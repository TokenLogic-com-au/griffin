"use client";

import { useState } from "react";
import { useAccount } from "wagmi";

import { ConnectWallet } from "@/components/ConnectWallet";
import { NetworkGuard } from "@/components/NetworkGuard";
import { DepositForm } from "@/components/DepositForm";
import { RedeemForm } from "@/components/RedeemForm";
import { FaucetPanel } from "@/components/FaucetPanel";
import { TokenIcon } from "@/components/TokenSelector";
import { useTokenBalances } from "@/hooks/useTokenBalances";
import { useMounted } from "@/hooks/useMounted";
import { formatTokenAmount } from "@/lib/formatting";
import { TOKENS } from "@/config/tokens";

type Tab = "deposit" | "redeem";

/** Sidebar savings account entry */
const SAVINGS_ACCOUNTS = [
  { symbol: "GHO", apy: "5.37" },
  { symbol: "USDC", apy: "5.30" },
  { symbol: "USDT", apy: "5.30" },
] as const;

export default function Home() {
  const [activeTab, setActiveTab] = useState<Tab>("deposit");
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedSidebarToken, setSelectedSidebarToken] = useState<string>("sGHO");
  const { isConnected } = useAccount();
  const mounted = useMounted();
  const connected = mounted && isConnected;
  const { balances, isLoading } = useTokenBalances();

  return (
    <NetworkGuard>
      <div className="flex min-h-screen flex-col">
        {/* ---- Navbar ---- */}
        <nav className="border-b border-[var(--border-secondary)]">
          <div className="mx-auto flex h-14 max-w-[1400px] items-center justify-between px-4 sm:px-6">
            <div className="flex items-center gap-1">
              <AaveGhost className="h-7 w-7" />
              <div className="ml-4 flex items-center gap-1">
                <NavTab active label="sGHO Router" badge="APY" />
                <NavTab label="Markets" />
                <NavTab label="Swap" />
              </div>
            </div>
            <div className="flex items-center gap-3">
              <a
                href="/dashboard"
                className="hidden rounded-md border border-[var(--border-primary)] bg-[var(--bg-surface)] px-3 py-1.5 text-xs font-medium text-[var(--text-muted)] transition-colors hover:text-[var(--text-secondary)] sm:block"
              >
                Dashboard
              </a>
              <a
                href="https://docs.aave.com/developers/getting-started/readme"
                target="_blank"
                rel="noopener noreferrer"
                className="hidden rounded-md border border-[var(--border-primary)] bg-[var(--bg-surface)] px-3 py-1.5 text-xs font-medium text-[var(--text-muted)] transition-colors hover:text-[var(--text-secondary)] sm:block"
              >
                Docs
              </a>
              <ChainBadge />
              <ConnectWallet />
            </div>
          </div>
        </nav>

        {/* ---- Page header ---- */}
        <div className="border-b border-[var(--border-secondary)] bg-[var(--bg-secondary)]">
          <div className="mx-auto flex max-w-[1400px] items-center justify-between px-4 pb-5 pt-6 sm:px-6">
            <h1 className="text-3xl font-bold text-[var(--text-primary)]">sGHO Router</h1>
            <div className="flex items-center gap-0 overflow-hidden rounded-md border border-[var(--border-primary)] bg-[var(--bg-surface)] text-xs">
              <div className="border-r border-[var(--border-primary)] px-3 py-1.5">
                <span className="text-[var(--text-muted)]">TVL: </span>
                <span className="font-bold text-[var(--text-primary)]">$263.51M</span>
              </div>
              <a
                href="https://aave.tokenlogic.xyz"
                target="_blank"
                rel="noopener noreferrer"
                className="border-l border-[var(--border-primary)] px-2 py-1.5 text-[var(--text-muted)] transition-colors hover:text-[var(--text-secondary)]"
              >
                <ExternalLinkIcon />
              </a>
            </div>
          </div>
        </div>

        {/* ---- Main content ---- */}
        <main className="mx-auto w-full max-w-[1400px] flex-1 px-4 py-8 sm:px-6">
          <div className="flex flex-col gap-8 lg:flex-row">
            {/* Left sidebar: savings accounts */}
            <div className="w-full flex-shrink-0 lg:w-52">
              <p className="mb-3 text-xs font-medium text-[var(--text-muted)]">Router accepted assets</p>
              <div className="space-y-2">
                {SAVINGS_ACCOUNTS.map((acct) => (
                  <button
                    key={acct.symbol}
                    onClick={() => setSelectedSidebarToken(acct.symbol)}
                    className={`flex w-full items-center justify-between rounded-lg border px-4 py-3 text-left transition-colors ${
                      selectedSidebarToken === acct.symbol
                        ? "border-[var(--aave-teal)] bg-[var(--bg-surface)]"
                        : "border-[var(--border-secondary)] bg-[var(--bg-secondary)] hover:border-[var(--border-primary)]"
                    }`}
                  >
                    <div className="flex items-center gap-2.5">
                      <TokenIcon symbol={acct.symbol} size="md" />
                      <span className="text-sm font-medium text-[var(--text-primary)]">{acct.symbol}</span>
                    </div>
                    <span className="text-sm tabular-nums text-[var(--text-secondary)]">{acct.apy}%</span>
                  </button>
                ))}
              </div>

              {/* sGHO vault highlight */}
              <p className="mb-3 mt-6 text-xs font-medium text-[var(--text-muted)]">Router token</p>
              <button
                onClick={() => setSelectedSidebarToken("sGHO")}
                className={`flex w-full flex-col gap-2 rounded-lg border px-4 py-3 text-left transition-colors ${
                  selectedSidebarToken === "sGHO"
                    ? "border-[var(--aave-teal)] bg-[var(--bg-surface)]"
                    : "border-[var(--border-secondary)] bg-[var(--bg-secondary)] hover:border-[var(--border-primary)]"
                }`}
              >
                <TokenIcon symbol="sGHO" size="md" />
                <div className="flex w-full items-center justify-between">
                  <span className="text-sm font-medium text-[var(--text-primary)]">sGHO</span>
                  <span className="text-sm tabular-nums text-[var(--aave-teal)]">5.37%</span>
                </div>
              </button>

              {/* Faucet (testnet) - shown in sidebar when connected */}
            </div>

            {/* Right: main content */}
            <div className="min-w-0 flex-1 space-y-6">
              {/* Hero card */}
              <div className="hero-card relative overflow-hidden rounded-xl border border-[var(--border-secondary)] p-8">
                {/* Background decoration */}
                <div className="pointer-events-none absolute inset-0 overflow-hidden">
                  <div className="absolute -right-20 -top-20 h-80 w-80 rounded-full bg-[var(--aave-teal)] opacity-[0.04] blur-3xl" />
                  <div className="absolute -bottom-10 right-20 h-40 w-40 rounded-full bg-[var(--aave-purple)] opacity-[0.06] blur-2xl" />
                </div>

                <div className="relative flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
                  <div className="max-w-lg">
                    <h2 className="mb-2 text-2xl font-bold leading-tight text-[var(--text-primary)] sm:text-3xl">
                      Deposit your stablecoins{" "}
                      <br className="hidden sm:block" />
                      and earn <span className="text-[var(--aave-teal)]">5.37% APY!</span>
                    </h2>
                    <div className="mb-4 flex items-center gap-2">
                      <div className="flex -space-x-1.5">
                        <TokenIcon symbol="GHO" size="sm" />
                        <TokenIcon symbol="USDC" size="sm" />
                        <TokenIcon symbol="USDT" size="sm" />
                      </div>
                      <span className="text-sm text-[var(--text-muted)]">
                        &raquo;
                      </span>
                      <TokenIcon symbol="sGHO" size="sm" />
                    </div>
                    <p className="text-sm leading-relaxed text-[var(--text-secondary)]">
                      Deposit your stablecoins into the sGHO vault.
                      <br />
                      USDC and USDT are routed through the GHO Stability Module for a transparent APY in sGHO.
                    </p>
                    <a
                      href="https://docs.gho.xyz/"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="mt-2 inline-flex items-center gap-1 text-sm font-medium text-[var(--aave-teal)] hover:underline"
                    >
                      Learn more <ExternalLinkIcon />
                    </a>
                  </div>

                  <div className="flex flex-shrink-0 items-center gap-3">
                    <button
                      onClick={() => { setActiveTab("deposit"); setModalOpen(true); }}
                      className="btn-primary whitespace-nowrap px-8"
                    >
                      Deposit
                    </button>
                    <button
                      onClick={() => { setActiveTab("redeem"); setModalOpen(true); }}
                      className="btn-ghost whitespace-nowrap"
                    >
                      Withdraw
                    </button>
                  </div>
                </div>
              </div>

              {/* Faucet - prominent on testnet */}
              <FaucetPanel />

              {/* Savings Rate / Chart section */}
              <div className="card">
                <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                  <div className="flex gap-0 overflow-hidden rounded-md border border-[var(--border-primary)]">
                    <button className="bg-[var(--bg-surface)] px-4 py-2 text-sm font-semibold text-[var(--text-primary)]">
                      APY
                    </button>
                    <button className="px-4 py-2 text-sm font-medium text-[var(--text-muted)] transition-colors hover:text-[var(--text-secondary)]">
                      Collateral Composition
                    </button>
                  </div>
                  <div className="flex gap-0 overflow-hidden rounded-md border border-[var(--border-primary)]">
                    {["1M", "3M", "1Y", "All"].map((range, i) => (
                      <button
                        key={range}
                        className={`px-3 py-1.5 text-xs font-medium transition-colors ${
                          i === 1
                            ? "bg-[var(--bg-surface)] text-[var(--text-primary)]"
                            : "text-[var(--text-muted)] hover:text-[var(--text-secondary)]"
                        }`}
                      >
                        {range}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Placeholder chart */}
                <div className="relative h-52 w-full overflow-hidden rounded-lg">
                  <div className="absolute inset-0 flex items-end">
                    <svg className="h-full w-full" viewBox="0 0 800 200" preserveAspectRatio="none">
                      <defs>
                        <linearGradient id="chartGrad" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="var(--aave-teal)" stopOpacity="0.3" />
                          <stop offset="100%" stopColor="var(--aave-teal)" stopOpacity="0.02" />
                        </linearGradient>
                      </defs>
                      <path
                        d="M0,60 L200,55 L400,50 L500,48 L600,50 L800,50 L800,200 L0,200 Z"
                        fill="url(#chartGrad)"
                      />
                      <path
                        d="M0,60 L200,55 L400,50 L500,48 L600,50 L800,50"
                        fill="none"
                        stroke="var(--aave-teal)"
                        strokeWidth="2"
                      />
                    </svg>
                  </div>
                  {/* Y-axis labels */}
                  <div className="pointer-events-none absolute left-0 top-0 flex h-full flex-col justify-between py-2 text-[10px] text-[var(--text-muted)]">
                    <span>5%</span>
                    <span>4%</span>
                    <span>3%</span>
                    <span>2%</span>
                    <span>1%</span>
                    <span>0%</span>
                  </div>
                </div>
              </div>

              {/* Supported assets table */}
              <div className="card">
                <h3 className="mb-5 text-lg font-bold text-[var(--text-primary)]">Supported assets</h3>
                <div className="overflow-x-auto">
                  <table className="w-full">
                    <thead>
                      <tr className="border-b border-[var(--border-secondary)]">
                        <th className="pb-3 text-left text-xs font-medium text-[var(--text-muted)]">Asset</th>
                        <th className="pb-3 text-right text-xs font-medium text-[var(--text-muted)]">Balance</th>
                        <th className="pb-3 text-right text-xs font-medium text-[var(--text-muted)]"></th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-[var(--border-secondary)]">
                      {([
                        { symbol: "GHO", label: "GHO", balance: balances.GHO, decimals: TOKENS.GHO.decimals },
                        { symbol: "USDC", label: "USDC", balance: balances.USDC, decimals: TOKENS.USDC.decimals },
                        { symbol: "USDT", label: "USDT", balance: balances.USDT, decimals: TOKENS.USDT.decimals },
                      ] as const).map((row) => (
                        <tr key={row.symbol} className="group">
                          <td className="py-4">
                            <div className="flex items-center gap-3">
                              <TokenIcon symbol={row.symbol} size="md" />
                              <span className="text-sm font-semibold text-[var(--text-primary)]">{row.label}</span>
                            </div>
                          </td>
                          <td className="py-4 text-right text-sm tabular-nums text-[var(--text-secondary)]">
                            {!connected ? (
                              <span className="text-[var(--text-muted)]">-</span>
                            ) : isLoading ? (
                              <span className="inline-block h-4 w-16 animate-pulse rounded bg-[var(--bg-hover)]" />
                            ) : (
                              formatTokenAmount(row.balance, row.decimals)
                            )}
                          </td>
                          <td className="py-4 text-right">
                            <div className="flex items-center justify-end gap-2">
                              <button
                                onClick={() => { setActiveTab("deposit"); setModalOpen(true); }}
                                className="rounded-md border border-[var(--border-primary)] bg-transparent px-4 py-1.5 text-xs font-medium text-[var(--text-secondary)] opacity-0 transition-all hover:border-[var(--text-muted)] hover:text-[var(--text-primary)] group-hover:opacity-100"
                              >
                                Deposit
                              </button>
                              <button className="text-[var(--text-muted)] opacity-0 transition-opacity hover:text-[var(--text-secondary)] group-hover:opacity-100">
                                <ThreeDotsIcon />
                              </button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        </main>

        {/* ---- Footer ---- */}
        <footer className="border-t border-[var(--border-secondary)] py-6">
          <div className="mx-auto flex max-w-[1400px] flex-col items-center justify-between gap-4 px-4 sm:flex-row sm:px-6">
            <div className="flex items-center gap-2 text-xs text-[var(--text-muted)]">
              <span>Built by</span>
              <a
                href="https://tokenlogic.xyz"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-1.5 font-semibold text-[var(--text-secondary)] transition-colors hover:text-[var(--text-primary)]"
              >
                <TokenLogicMark className="h-4 w-4" />
                TokenLogic
              </a>
              <span className="text-[var(--border-primary)]">|</span>
              <span>Contracts deployed by Aave DAO</span>
            </div>
            <div className="flex items-center gap-4 text-xs text-[var(--text-muted)]">
              <a href="https://docs.gho.xyz/" target="_blank" rel="noopener noreferrer" className="hover:text-[var(--text-secondary)]">Docs</a>
              <a href="https://github.com/aave/gho-core/tree/main/audits" target="_blank" rel="noopener noreferrer" className="hover:text-[var(--text-secondary)]">Security</a>
              <a href="https://twitter.com/Token_Logic" target="_blank" rel="noopener noreferrer" className="hover:text-[var(--text-secondary)]">Twitter</a>
              <a href="https://aave.tokenlogic.xyz" target="_blank" rel="noopener noreferrer" className="hover:text-[var(--text-secondary)]">Dashboard</a>
            </div>
          </div>
        </footer>

        {/* ---- Deposit / Withdraw Modal ---- */}
        {modalOpen && (
          <div
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
            onClick={(e) => { if (e.target === e.currentTarget) setModalOpen(false); }}
          >
            <div className="relative w-full max-w-lg animate-modal-in rounded-xl border border-[var(--border-secondary)] bg-[var(--bg-secondary)] p-6 shadow-2xl shadow-black/40">
              {/* Close button */}
              <button
                onClick={() => setModalOpen(false)}
                className="absolute right-4 top-4 text-[var(--text-muted)] transition-colors hover:text-[var(--text-primary)]"
              >
                <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>

              {/* Tabs */}
              <div className="mb-6 flex gap-8 border-b border-[var(--border-secondary)]">
                <button
                  onClick={() => setActiveTab("deposit")}
                  className={activeTab === "deposit" ? "tab-active" : "tab-inactive"}
                  data-testid="tab-deposit"
                >
                  Deposit
                </button>
                <button
                  onClick={() => setActiveTab("redeem")}
                  className={activeTab === "redeem" ? "tab-active" : "tab-inactive"}
                  data-testid="tab-redeem"
                >
                  Withdraw
                </button>
              </div>

              {!connected ? (
                <div className="py-14 text-center">
                  <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-[var(--bg-surface)]">
                    <svg className="h-6 w-6 text-[var(--text-muted)]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                    </svg>
                  </div>
                  <p className="mb-5 text-sm text-[var(--text-muted)]">
                    Connect a wallet to get started
                  </p>
                  <ConnectWallet />
                </div>
              ) : activeTab === "deposit" ? (
                <DepositForm />
              ) : (
                <RedeemForm />
              )}
            </div>
          </div>
        )}
      </div>
    </NetworkGuard>
  );
}

/* ---- Helper components ---- */

function NavTab({ label, active, badge }: { label: string; active?: boolean; badge?: string }) {
  return (
    <button
      className={`flex items-center gap-1.5 rounded-md px-3 py-1.5 text-sm font-semibold transition-colors ${
        active
          ? "bg-[var(--aave-teal)]/10 text-[var(--aave-teal)]"
          : "text-[var(--text-muted)] hover:text-[var(--text-secondary)]"
      }`}
    >
      {label}
      {badge && (
        <span className="rounded bg-[var(--aave-teal)] px-1.5 py-0.5 text-[10px] font-bold text-white">
          {badge}
        </span>
      )}
    </button>
  );
}

function ChainBadge() {
  return (
    <div className="hidden items-center gap-1.5 rounded-md border border-[var(--border-primary)] bg-[var(--bg-surface)] px-2.5 py-1.5 sm:flex">
      <div className="h-2 w-2 rounded-full bg-aave-teal shadow-[0_0_6px_rgba(46,186,198,0.4)]" />
      <span className="text-xs font-medium text-[var(--text-secondary)]">Ethereum</span>
    </div>
  );
}

function ExternalLinkIcon() {
  return (
    <svg className="inline h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
    </svg>
  );
}

function ThreeDotsIcon() {
  return (
    <svg className="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
      <circle cx="12" cy="5" r="1.5" />
      <circle cx="12" cy="12" r="1.5" />
      <circle cx="12" cy="19" r="1.5" />
    </svg>
  );
}

/** Aave ghost logo mark */
function AaveGhost({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="aaveGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#B6509E" />
          <stop offset="100%" stopColor="#2EBAC6" />
        </linearGradient>
      </defs>
      <circle cx="20" cy="20" r="20" fill="url(#aaveGrad)" />
      <path
        d="M27.5 28.5H25.2C24.8 28.5 24.5 28.3 24.3 28L20.8 21.4C20.6 21 20.2 21 20 21.4L18.2 24.8C18 25.1 17.7 25.3 17.3 25.3H12.5C12 25.3 11.7 24.8 12 24.4L19.2 11.6C19.4 11.2 19.7 11 20 11C20.3 11 20.6 11.2 20.8 11.6L28 24.4C28.3 24.8 28 25.3 27.5 25.3H25.7C25.3 25.3 25 25.5 24.8 25.8L25 26.2C25.2 26.5 25 26.8 24.7 26.8H24.5C24.8 27.6 25.3 28.5 27.5 28.5Z"
        fill="white"
      />
    </svg>
  );
}

/** TokenLogic mark */
function TokenLogicMark({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width="20" height="20" rx="4" fill="currentColor" fillOpacity="0.15" />
      <path d="M5 7h10M10 7v8" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    </svg>
  );
}

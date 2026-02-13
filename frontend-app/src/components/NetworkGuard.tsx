"use client";

import { useNetworkGuard } from "@/hooks/useNetworkGuard";

/**
 * Overlay blocking interaction when wallet is on the wrong network.
 */
export function NetworkGuard({ children }: { children: React.ReactNode }) {
  const {
    needsSwitch,
    isSwitching,
    canSwitch,
    currentChainName,
    targetChainName,
    targetChainId,
    switchToCorrectNetwork,
  } = useNetworkGuard();

  if (!needsSwitch) return <>{children}</>;

  return (
    <>
      {children}
      <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
        <div className="card mx-4 max-w-sm text-center">
          <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-[var(--warning)]/10">
            <svg className="h-6 w-6 text-[var(--warning)]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <h2 className="mb-2 text-lg font-bold">Wrong Network</h2>
          <p className="mb-6 text-sm text-[var(--text-secondary)]">
            You&apos;re connected to{" "}
            <span className="font-semibold text-[var(--text-primary)]">{currentChainName}</span>.
            Please switch to{" "}
            <span className="font-semibold text-[var(--text-primary)]">{targetChainName}</span>.
          </p>
          {canSwitch ? (
            <button
              onClick={switchToCorrectNetwork}
              disabled={isSwitching}
              className="btn-primary w-full"
            >
              {isSwitching ? "Switching..." : `Switch to ${targetChainName}`}
            </button>
          ) : (
            <p className="rounded-md border border-[var(--warning)]/30 bg-[var(--warning)]/10 p-3 text-xs text-[var(--text-secondary)]">
              This wallet does not support automatic network switching. Please switch manually
              to chain ID {targetChainId} in your wallet, then return to this page.
            </p>
          )}
        </div>
      </div>
    </>
  );
}

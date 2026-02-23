"use client";

import type { TransactionStep } from "@/types";
import { getTxUrl } from "@/lib/formatting";
import { targetChain } from "@/config/chains";

interface TransactionStatusProps {
  steps: TransactionStep[];
  onReset?: () => void;
}

/**
 * Aave-style multi-step transaction progress.
 */
export function TransactionStatus({ steps, onReset }: TransactionStatusProps) {
  const allDone = steps.every((s) => s.status === "success");
  const hasError = steps.some((s) => s.status === "error");

  return (
    <div className="space-y-4">
      {steps.map((step, i) => (
        <div
          key={i}
          className="flex items-center gap-3 rounded-lg border border-[var(--border-secondary)] bg-[var(--bg-surface)] px-4 py-3"
        >
          <StepIcon status={step.status} />
          <div className="min-w-0 flex-1">
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-[var(--text-primary)]">{step.label}</span>
              <StatusLabel status={step.status} />
            </div>
            {step.txHash && (
              <a
                href={getTxUrl(
                  step.txHash,
                  targetChain.id,
                  targetChain.blockExplorers?.default.url
                )}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-[var(--aave-teal)] hover:underline"
              >
                View transaction &rarr;
              </a>
            )}
            {step.error && (
              <p className="mt-0.5 text-xs text-[var(--error)]">{step.error}</p>
            )}
          </div>
        </div>
      ))}

      {allDone && (
        <div className="rounded-lg bg-[var(--success)]/10 px-4 py-3 text-center text-sm font-medium text-[var(--success)]">
          All transactions completed successfully
        </div>
      )}

      {(allDone || hasError) && onReset && (
        <button onClick={onReset} className="btn-primary w-full">
          {allDone ? "Start new transaction" : "Try again"}
        </button>
      )}
    </div>
  );
}

function StepIcon({ status }: { status: TransactionStep["status"] }) {
  const base = "flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full";
  switch (status) {
    case "success":
      return (
        <div className={`${base} bg-[var(--success)]/15`}>
          <svg className="h-4 w-4 text-[var(--success)]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
          </svg>
        </div>
      );
    case "pending":
    case "confirming":
      return (
        <div className={`${base} bg-[var(--aave-teal)]/15`}>
          <svg className="h-4 w-4 animate-spin text-[var(--aave-teal)]" viewBox="0 0 24 24" fill="none">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
          </svg>
        </div>
      );
    case "error":
      return (
        <div className={`${base} bg-[var(--error)]/15`}>
          <svg className="h-4 w-4 text-[var(--error)]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </div>
      );
    default:
      return <div className={`${base} border border-[var(--border-primary)]`} />;
  }
}

function StatusLabel({ status }: { status: TransactionStep["status"] }) {
  const map: Record<TransactionStep["status"], { text: string; cls: string }> = {
    idle: { text: "Waiting", cls: "text-[var(--text-muted)]" },
    pending: { text: "Confirm in wallet", cls: "text-[var(--aave-teal)]" },
    confirming: { text: "Confirming...", cls: "text-[var(--aave-teal)]" },
    success: { text: "Confirmed", cls: "text-[var(--success)]" },
    error: { text: "Failed", cls: "text-[var(--error)]" },
  };
  const { text, cls } = map[status];
  return <span className={`text-xs font-medium ${cls}`}>{text}</span>;
}

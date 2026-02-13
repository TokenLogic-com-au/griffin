"use client";

import type { ParsedError } from "@/lib/errors";

interface ErrorDisplayProps {
  error: ParsedError | undefined;
  onDismiss?: () => void;
}

/**
 * Aave-style inline error/warning alert.
 */
export function ErrorDisplay({ error, onDismiss }: ErrorDisplayProps) {
  if (!error) return null;

  const isUserRejection = error.isUserRejection;
  const bg = isUserRejection ? "bg-[var(--warning)]/8" : "bg-[var(--error)]/8";
  const border = isUserRejection ? "border-[var(--warning)]/20" : "border-[var(--error)]/20";
  const text = isUserRejection ? "text-[var(--warning)]" : "text-[var(--error)]";

  return (
    <div
      className={`flex items-start gap-3 rounded-lg border ${border} ${bg} px-4 py-3`}
      role="alert"
      data-testid="error-display"
    >
      <svg className={`mt-0.5 h-4 w-4 flex-shrink-0 ${text}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      <div className="min-w-0 flex-1">
        {!isUserRejection && (
          <p className={`mb-0.5 text-[10px] font-semibold uppercase tracking-wider ${text} opacity-60`}>
            {error.name}
          </p>
        )}
        <p className={`text-sm ${text}`}>{error.message}</p>
      </div>
      {onDismiss && (
        <button
          onClick={onDismiss}
          className={`mt-0.5 ${text} opacity-40 hover:opacity-80`}
          aria-label="Dismiss"
        >
          <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      )}
    </div>
  );
}

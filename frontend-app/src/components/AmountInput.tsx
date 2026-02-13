"use client";

import { formatTokenAmount } from "@/lib/formatting";
import type { TokenInfo } from "@/types";

interface AmountInputProps {
  value: string;
  onChange: (value: string) => void;
  token: TokenInfo;
  balance?: bigint;
  label?: string;
  disabled?: boolean;
  error?: string;
  /** Right-side slot, e.g. a TokenSelector */
  endAdornment?: React.ReactNode;
}

/**
 * Spark-style amount input: big number left, token selector right, balance + MAX below.
 */
export function AmountInput({
  value,
  onChange,
  token,
  balance,
  label = "Amount",
  disabled = false,
  error,
  endAdornment,
}: AmountInputProps) {
  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value;
    if (val === "" || /^\d*\.?\d*$/.test(val)) {
      onChange(val);
    }
  };

  const handleMax = () => {
    if (balance !== undefined && balance > 0n) {
      const formatted = formatTokenAmount(balance, token.decimals, token.decimals);
      onChange(formatted.replace(/,/g, ""));
    }
  };

  return (
    <div>
      <label className="mb-2 block text-xs font-medium text-[var(--text-muted)]">
        {label}
      </label>
      <div className={`input-box ${error ? "!border-[var(--error)]" : ""}`}>
        <div className="min-w-0 flex-1">
          <input
            type="text"
            inputMode="decimal"
            value={value}
            onChange={handleChange}
            disabled={disabled}
            placeholder="0"
            className="input-field"
            data-testid="amount-input"
          />
        </div>
        {endAdornment && <div className="ml-3">{endAdornment}</div>}
      </div>

      {/* Balance row */}
      <div className="mt-2 flex items-center justify-between px-1">
        {balance !== undefined ? (
          <span className="text-xs text-[var(--text-muted)]">
            Balance: {formatTokenAmount(balance, token.decimals)}{" "}
            <span className="text-[var(--text-secondary)]">{token.symbol}</span>
          </span>
        ) : (
          <span />
        )}
        {balance !== undefined && balance > 0n && (
          <button
            type="button"
            onClick={handleMax}
            disabled={disabled}
            className="text-xs font-semibold text-[var(--aave-teal)] transition-colors hover:text-[var(--text-primary)]"
            data-testid="max-button"
          >
            MAX
          </button>
        )}
      </div>

      {error && (
        <p className="mt-1 px-1 text-xs text-[var(--error)]" data-testid="amount-error">
          {error}
        </p>
      )}
    </div>
  );
}

"use client";

import { useState, useRef, useEffect } from "react";
import type { SupportedToken } from "@/types";
import { TOKEN_LIST, getTokenBySymbol } from "@/config/tokens";

interface TokenSelectorProps {
  selected: SupportedToken;
  onChange: (token: SupportedToken) => void;
  tokens?: SupportedToken[];
  disabled?: boolean;
}

export function TokenSelector({
  selected,
  onChange,
  tokens,
  disabled = false,
}: TokenSelectorProps) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const selectedToken = getTokenBySymbol(selected);

  const availableTokens = tokens ? tokens.map(getTokenBySymbol) : TOKEN_LIST;

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, []);

  return (
    <div ref={ref} className="relative flex-shrink-0">
      <button
        type="button"
        onClick={() => !disabled && setOpen(!open)}
        disabled={disabled}
        className="flex items-center gap-2 rounded-md border border-[var(--border-primary)] bg-[var(--bg-surface)] px-3 py-2 text-sm font-semibold transition-colors hover:bg-[var(--bg-hover)] disabled:cursor-not-allowed disabled:opacity-50"
        aria-label="Select token"
        data-testid="token-selector"
      >
        <TokenIcon symbol={selectedToken.symbol} size="sm" />
        <span>{selectedToken.symbol}</span>
        <ChevronDown />
      </button>

      {open && (
        <div className="absolute right-0 z-30 mt-1 w-52 overflow-hidden rounded-lg border border-[var(--border-primary)] bg-[var(--bg-secondary)] shadow-xl shadow-black/40">
          {availableTokens.map((token) => (
            <button
              key={token.symbol}
              type="button"
              onClick={() => { onChange(token.symbol); setOpen(false); }}
              className={`flex w-full items-center gap-3 px-4 py-3 text-left text-sm transition-colors hover:bg-[var(--bg-hover)] ${
                token.symbol === selected ? "text-[var(--aave-teal)]" : "text-[var(--text-primary)]"
              }`}
              data-testid={`token-option-${token.symbol}`}
            >
              <TokenIcon symbol={token.symbol} size="md" />
              <div>
                <div className="font-semibold">{token.symbol}</div>
                <div className="text-xs text-[var(--text-muted)]">{token.name}</div>
              </div>
              {token.symbol === selected && (
                <svg className="ml-auto h-4 w-4 text-[var(--aave-teal)]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
                </svg>
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

export function TokenIcon({ symbol, size = "md" }: { symbol: string; size?: "sm" | "md" | "lg" }) {
  const sizeClasses = { sm: "h-5 w-5 text-[9px]", md: "h-6 w-6 text-[10px]", lg: "h-8 w-8 text-xs" };

  const colors: Record<string, string> = {
    GHO: "bg-[#b6509e]",
    USDC: "bg-[#2775ca]",
    USDT: "bg-[#26a17b]",
    sGHO: "bg-gradient-to-br from-[#b6509e] to-[#2ebac6]",
  };

  const bg = colors[symbol] || "bg-[var(--bg-hover)]";
  const letter = symbol === "sGHO" ? "S" : symbol[0];

  return (
    <div className={`flex items-center justify-center rounded-full font-bold text-white ${bg} ${sizeClasses[size]}`}>
      {letter}
    </div>
  );
}

function ChevronDown() {
  return (
    <svg className="h-3.5 w-3.5 text-[var(--text-muted)]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M19 9l-7 7-7-7" />
    </svg>
  );
}

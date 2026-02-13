"use client";

import { useState, useMemo, useCallback, useEffect } from "react";
import { parseUnits } from "viem";

import { TokenSelector } from "./TokenSelector";
import { AmountInput } from "./AmountInput";
import { TransactionPreview } from "./TransactionPreview";
import { TransactionStatus } from "./TransactionStatus";
import { ErrorDisplay } from "./ErrorDisplay";

import { useTokenBalances } from "@/hooks/useTokenBalances";
import { useAllowance } from "@/hooks/useAllowance";
import { usePreviewDeposit } from "@/hooks/usePreviewDeposit";
import { useApprove } from "@/hooks/useApprove";
import { useDeposit } from "@/hooks/useDeposit";

import { getTokenBySymbol, DEFAULT_SLIPPAGE_BPS } from "@/config/tokens";
import { validateAmount, applySlippage } from "@/lib/validation";
import { formatTokenAmount } from "@/lib/formatting";
import { trackEvent } from "@/lib/analytics";
import type { SupportedToken, TransactionStep } from "@/types";

export function DepositForm() {
  const [selectedToken, setSelectedToken] = useState<SupportedToken>("GHO");
  const [amountStr, setAmountStr] = useState("");
  const [slippageBps, setSlippageBps] = useState(DEFAULT_SLIPPAGE_BPS);
  const [showSettings, setShowSettings] = useState(false);

  const token = getTokenBySymbol(selectedToken);
  const { balances, refetch: refetchBalances } = useTokenBalances();

  const parsedAmount = useMemo(() => {
    if (!amountStr) return undefined;
    try {
      const val = parseUnits(amountStr, token.decimals);
      return val > 0n ? val : undefined;
    } catch {
      return undefined;
    }
  }, [amountStr, token.decimals]);

  const balance = balances[selectedToken as keyof typeof balances] ?? 0n;

  const validation = useMemo(
    () => (amountStr ? validateAmount(amountStr, token, balance) : { valid: false }),
    [amountStr, token, balance]
  );

  const { allowance, refetch: refetchAllowance } = useAllowance(token.address);
  const needsApproval = parsedAmount !== undefined && allowance < parsedAmount;

  const { preview, isLoading: previewLoading } = usePreviewDeposit(token.address, parsedAmount);

  const {
    approve, txHash: approveTxHash, status: approveStatus,
    error: approveError, reset: resetApprove,
  } = useApprove();

  const {
    deposit, txHash: depositTxHash, status: depositStatus,
    error: depositError, depositEvent, dustEvents, reset: resetDeposit,
  } = useDeposit();

  useEffect(() => {
    if (approveStatus === "success") refetchAllowance();
  }, [approveStatus, refetchAllowance]);

  useEffect(() => {
    if (depositStatus === "success") {
      refetchBalances();
      refetchAllowance();
      if (depositTxHash) {
        trackEvent({
          type: "deposit_completed", token: selectedToken,
          shares: depositEvent?.sharesReceived?.toString() ?? "0", txHash: depositTxHash,
        });
      }
    }
  }, [depositStatus, refetchBalances, refetchAllowance, depositTxHash, selectedToken, depositEvent]);

  const steps: TransactionStep[] = useMemo(() => {
    const result: TransactionStep[] = [];
    if (needsApproval || approveStatus !== "idle") {
      result.push({
        label: `Approve ${selectedToken}`,
        status: approveStatus, txHash: approveTxHash, error: approveError?.message,
      });
    }
    if (depositStatus !== "idle" || approveStatus === "success" || !needsApproval) {
      result.push({
        label: "Deposit to sGHO",
        status: depositStatus, txHash: depositTxHash, error: depositError?.message,
      });
    }
    return result;
  }, [needsApproval, approveStatus, approveTxHash, approveError, depositStatus, depositTxHash, depositError, selectedToken]);

  const isInProgress = ["pending", "confirming"].includes(approveStatus) || ["pending", "confirming"].includes(depositStatus);

  const getMinOutputAmount = useCallback(
    (inputAmount: bigint) =>
      applySlippage(
        selectedToken === "GHO" ? inputAmount : (preview?.ghoAmount ?? 0n),
        slippageBps
      ),
    [selectedToken, preview, slippageBps]
  );

  const handleSubmit = useCallback(() => {
    if (!parsedAmount || !validation.valid) return;
    const minOutput = getMinOutputAmount(parsedAmount);
    if (needsApproval) {
      approve(token.address, parsedAmount, selectedToken);
    } else {
      deposit(token.address, parsedAmount, minOutput, selectedToken);
    }
  }, [parsedAmount, validation.valid, needsApproval, approve, selectedToken, token.address, deposit, getMinOutputAmount]);

  useEffect(() => {
    if (approveStatus === "success" && depositStatus === "idle" && parsedAmount) {
      const minOutput = getMinOutputAmount(parsedAmount);
      deposit(token.address, parsedAmount, minOutput, selectedToken);
    }
  }, [approveStatus, depositStatus, parsedAmount, selectedToken, deposit, token.address, getMinOutputAmount]);

  const handleReset = () => { resetApprove(); resetDeposit(); setAmountStr(""); };

  let buttonLabel = "Enter an amount";
  let buttonDisabled = true;
  if (!amountStr) { buttonLabel = "Enter an amount"; }
  else if (!validation.valid) { buttonLabel = validation.error ?? "Invalid input"; }
  else if (isInProgress) { buttonLabel = "Processing..."; }
  else if (previewLoading) { buttonLabel = needsApproval ? "Approve & Deposit" : "Deposit"; buttonDisabled = false; }
  else if (needsApproval) { buttonLabel = `Approve & Deposit`; buttonDisabled = false; }
  else if (validation.valid) { buttonLabel = "Deposit"; buttonDisabled = false; }

  const showStepper = approveStatus !== "idle" || depositStatus !== "idle";

  return (
    <div className="space-y-5">
      {/* Amount input with token selector */}
      <AmountInput
        value={amountStr}
        onChange={setAmountStr}
        token={token}
        balance={balance}
        label="Amount"
        disabled={isInProgress}
        error={amountStr && !validation.valid ? validation.error : undefined}
        endAdornment={
          <TokenSelector
            selected={selectedToken}
            onChange={(t) => { setSelectedToken(t); setAmountStr(""); resetApprove(); resetDeposit(); }}
            disabled={isInProgress}
          />
        }
      />

      {/* Settings row */}
      <div className="flex items-center justify-between px-1">
        <button
          type="button"
          onClick={() => setShowSettings(!showSettings)}
          className="flex items-center gap-1 text-xs text-[var(--text-muted)] transition-colors hover:text-[var(--text-secondary)]"
        >
          <svg className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.573-1.066z" />
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
          Slippage {(slippageBps / 100).toFixed(1)}%
        </button>
      </div>
      {showSettings && (
        <div className="flex gap-1.5 px-1">
          {[10, 50, 100, 200].map((bps) => (
            <button
              key={bps}
              type="button"
              onClick={() => setSlippageBps(bps)}
              className={`rounded-md px-3 py-1.5 text-xs font-medium transition-colors ${
                slippageBps === bps
                  ? "bg-[var(--aave-teal)]/15 text-[var(--aave-teal)]"
                  : "bg-[var(--bg-surface)] text-[var(--text-muted)] hover:text-[var(--text-secondary)]"
              }`}
            >
              {(bps / 100).toFixed(1)}%
            </button>
          ))}
        </div>
      )}

      {/* Preview */}
      {parsedAmount && parsedAmount > 0n && (
        <TransactionPreview
          type="deposit"
          preview={preview}
          inputToken={selectedToken}
          slippageBps={slippageBps}
        />
      )}

      {/* Stepper */}
      {showStepper && <TransactionStatus steps={steps} onReset={handleReset} />}

      {/* Errors */}
      {!showStepper && (approveError || depositError) && (
        <ErrorDisplay error={approveError ?? depositError} onDismiss={() => { resetApprove(); resetDeposit(); }} />
      )}

      {/* Success */}
      {depositEvent && depositStatus === "success" && (
        <div className="flex items-center gap-3 rounded-lg bg-[var(--success)]/8 px-4 py-3">
          <svg className="h-5 w-5 flex-shrink-0 text-[var(--success)]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
          </svg>
          <div>
            <p className="text-sm font-medium text-[var(--success)]">Deposit successful</p>
            <p className="text-xs text-[var(--text-muted)]">
              Received {formatTokenAmount(depositEvent.sharesReceived, 18)} sGHO
              {dustEvents.length > 0 && " (dust returned)"}
            </p>
          </div>
        </div>
      )}

      {/* Action button */}
      {!showStepper && (
        <button
          onClick={handleSubmit}
          disabled={buttonDisabled || isInProgress}
          className="btn-primary w-full"
          data-testid="deposit-button"
        >
          {buttonLabel}
        </button>
      )}
    </div>
  );
}

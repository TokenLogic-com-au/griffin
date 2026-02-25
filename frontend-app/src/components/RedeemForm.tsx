"use client";

import { useState, useMemo, useCallback, useEffect } from "react";
import { parseUnits } from "viem";

import { TokenSelector } from "./TokenSelector";
import { AmountInput } from "./AmountInput";
import { TransactionPreview } from "./TransactionPreview";
import { TransactionStatus } from "./TransactionStatus";
import { ErrorDisplay } from "./ErrorDisplay";

import { useTokenBalances } from "@/hooks/useTokenBalances";
import { useSGHOAllowance } from "@/hooks/useAllowance";
import { usePreviewRedeem } from "@/hooks/usePreviewRedeem";
import { useApprove } from "@/hooks/useApprove";
import { useRedeem } from "@/hooks/useRedeem";

import { getTokenBySymbol } from "@/config/tokens";
import { addresses } from "@/config/addresses";
import { validateShares } from "@/lib/validation";
import { formatTokenAmount } from "@/lib/formatting";
import { trackEvent } from "@/lib/analytics";
import type { SupportedToken, TransactionStep } from "@/types";

export function RedeemForm() {
  const [outputToken, setOutputToken] = useState<SupportedToken>("GHO");
  const [sharesStr, setSharesStr] = useState("");

  const token = getTokenBySymbol(outputToken);
  const { balances, refetch: refetchBalances } = useTokenBalances();
  const sGHOBalance = balances.sGHO ?? 0n;

  const sGHOTokenInfo = useMemo(
    () => ({ symbol: "sGHO" as SupportedToken, name: "sGHO Shares", address: addresses.sGHO, decimals: 18, icon: "" }),
    []
  );

  const parsedShares = useMemo(() => {
    if (!sharesStr) return undefined;
    try {
      const val = parseUnits(sharesStr, 18);
      return val > 0n ? val : undefined;
    } catch {
      return undefined;
    }
  }, [sharesStr]);

  const validation = useMemo(
    () => (sharesStr ? validateShares(sharesStr, sGHOBalance) : { valid: false }),
    [sharesStr, sGHOBalance]
  );

  const { preview, isLoading: previewLoading } = usePreviewRedeem(parsedShares, token.address);

  const { allowance, refetch: refetchAllowance } = useSGHOAllowance();
  const needsApproval = parsedShares !== undefined && allowance < parsedShares;

  const {
    approve, txHash: approveTxHash, status: approveStatus,
    error: approveError, reset: resetApprove,
  } = useApprove();

  const {
    redeem, txHash: redeemTxHash, status: redeemStatus,
    error: redeemError, redeemEvent, dustEvents, reset: resetRedeem,
  } = useRedeem();

  useEffect(() => {
    if (approveStatus === "success") refetchAllowance();
  }, [approveStatus, refetchAllowance]);

  useEffect(() => {
    if (redeemStatus === "success") {
      refetchBalances();
      refetchAllowance();
      if (redeemTxHash) {
        trackEvent({
          type: "redeem_completed",
          token: outputToken,
          amountOut: redeemEvent?.outputAmount?.toString() ?? "0",
          txHash: redeemTxHash,
        });
      }
    }
  }, [redeemStatus, refetchBalances, refetchAllowance, redeemTxHash, outputToken, redeemEvent]);

  const steps: TransactionStep[] = useMemo(() => {
    const result: TransactionStep[] = [];

    if (needsApproval || approveStatus !== "idle") {
      result.push({
        label: "Approve sGHO",
        status: approveStatus,
        txHash: approveTxHash,
        error: approveError?.message,
      });
    }

    if (redeemStatus !== "idle" || approveStatus === "success" || !needsApproval) {
      result.push({
        label: `Redeem to ${outputToken}`,
        status: redeemStatus,
        txHash: redeemTxHash,
        error: redeemError?.message,
      });
    }

    return result;
  }, [needsApproval, approveStatus, approveTxHash, approveError, redeemStatus, redeemTxHash, redeemError, outputToken]);

  const isInProgress =
    ["pending", "confirming"].includes(approveStatus) ||
    ["pending", "confirming"].includes(redeemStatus);
  const awaitingRedeemAction = approveStatus === "success" && redeemStatus === "idle";

  const handleSubmit = useCallback(() => {
    if (!parsedShares || !validation.valid || !preview) return;

    if (needsApproval && approveStatus === "idle") {
      approve(addresses.sGHO, parsedShares);
      return;
    }

    if (redeemStatus === "idle") {
      redeem(parsedShares, token.address, preview.estimatedOutput, outputToken);
    }
  }, [parsedShares, validation.valid, preview, needsApproval, approveStatus, approve, redeemStatus, redeem, token.address, outputToken]);

  const handleReset = () => {
    resetApprove();
    resetRedeem();
    setSharesStr("");
  };

  let buttonLabel = "Enter shares amount";
  let buttonDisabled = true;
  if (!sharesStr) {
    buttonLabel = "Enter shares amount";
  } else if (!validation.valid) {
    buttonLabel = validation.error ?? "Invalid input";
  } else if (previewLoading) {
    buttonLabel = "Fetching quote...";
  } else if (isInProgress) {
    buttonLabel = "Processing...";
  } else if (awaitingRedeemAction) {
    buttonLabel = "Redeem";
    buttonDisabled = false;
  } else if (needsApproval) {
    buttonLabel = "Approve & Redeem";
    buttonDisabled = false;
  } else if (validation.valid) {
    buttonLabel = "Redeem";
    buttonDisabled = false;
  }

  const showStepper = approveStatus !== "idle" || redeemStatus !== "idle";
  const showActionButton = !showStepper || awaitingRedeemAction;
  const outputDecimals = outputToken === "GHO" ? 18 : 6;
  const showSuccess = redeemStatus === "success" && !!redeemEvent;
  const successAmount = redeemEvent?.outputAmount ?? 0n;
  const rootError = approveError ?? redeemError;

  return (
    <div className="space-y-5">
      {/* Shares input */}
      <AmountInput
        value={sharesStr}
        onChange={setSharesStr}
        token={sGHOTokenInfo}
        balance={sGHOBalance}
        label="sGHO shares to redeem"
        disabled={isInProgress}
        error={sharesStr && !validation.valid ? validation.error : undefined}
      />

      {/* Receive as */}
      <div className="flex items-center justify-between rounded-lg border border-[var(--border-secondary)] bg-[var(--input-bg)] px-4 py-3">
        <span className="text-sm text-[var(--text-muted)]">Receive as</span>
        <TokenSelector
          selected={outputToken}
          onChange={(t) => {
            setOutputToken(t);
            resetApprove();
            resetRedeem();
          }}
          disabled={isInProgress}
        />
      </div>

      {/* Preview */}
      {parsedShares && parsedShares > 0n && (
        <TransactionPreview type="redeem" preview={preview} outputToken={outputToken} />
      )}

      {/* Stepper */}
      {showStepper && <TransactionStatus steps={steps} onReset={handleReset} />}

      {/* Errors */}
      {!showStepper && rootError && (
        <ErrorDisplay
          error={rootError}
          onDismiss={() => {
            resetApprove();
            resetRedeem();
          }}
        />
      )}

      {/* Success */}
      {showSuccess && (
        <div className="flex items-center gap-3 rounded-lg bg-[var(--success)]/8 px-4 py-3">
          <svg className="h-5 w-5 flex-shrink-0 text-[var(--success)]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
          </svg>
          <div>
            <p className="text-sm font-medium text-[var(--success)]">Redemption successful</p>
            <p className="text-xs text-[var(--text-muted)]">
              Received {formatTokenAmount(successAmount, outputDecimals)} {outputToken}
              {dustEvents.length > 0 && " (dust returned)"}
            </p>
          </div>
        </div>
      )}

      {/* Action button */}
      {showActionButton && (
        <button onClick={handleSubmit} disabled={buttonDisabled || isInProgress} className="btn-primary w-full" data-testid="redeem-button">
          {buttonLabel}
        </button>
      )}
    </div>
  );
}

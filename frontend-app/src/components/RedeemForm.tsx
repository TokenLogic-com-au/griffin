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
import { usePreviewRedeem } from "@/hooks/usePreviewRedeem";
import { useApprove } from "@/hooks/useApprove";
import { useRedeem } from "@/hooks/useRedeem";
import { useRedeemShares } from "@/hooks/useRedeemShares";

import { getTokenBySymbol } from "@/config/tokens";
import { addresses } from "@/config/addresses";
import { validateShares } from "@/lib/validation";
import { formatTokenAmount } from "@/lib/formatting";
import { trackEvent } from "@/lib/analytics";
import type { SupportedToken, TransactionStep } from "@/types";

export function RedeemForm() {
  const [outputToken, setOutputToken] = useState<SupportedToken>("GHO");
  const [sharesStr, setSharesStr] = useState("");
  const [preRedeemGhoBalance, setPreRedeemGhoBalance] = useState<bigint | undefined>();
  const [redeemedGhoAmount, setRedeemedGhoAmount] = useState<bigint | undefined>();

  const token = getTokenBySymbol(outputToken);
  const { balances, refetch: refetchBalances } = useTokenBalances();
  const sGHOBalance = balances.sGHO ?? 0n;
  const isGHOOutput = outputToken === "GHO";

  const sGHOTokenInfo = useMemo(
    () => ({ symbol: "sGHO" as SupportedToken, name: "sGHO Shares", address: addresses.sGHO, decimals: 18, icon: "" }),
    []
  );

  const parsedShares = useMemo(() => {
    if (!sharesStr) return undefined;
    try { const val = parseUnits(sharesStr, 18); return val > 0n ? val : undefined; } catch { return undefined; }
  }, [sharesStr]);

  const validation = useMemo(
    () => (sharesStr ? validateShares(sharesStr, sGHOBalance) : { valid: false }),
    [sharesStr, sGHOBalance]
  );

  const { preview, isLoading: previewLoading } = usePreviewRedeem(parsedShares, token.address);
  const ghoAmountForSwap = !isGHOOutput ? (redeemedGhoAmount ?? preview?.ghoAmount) : undefined;

  const { allowance, refetch: refetchAllowance } = useAllowance(addresses.GHO);
  const needsApproval = !isGHOOutput && ghoAmountForSwap !== undefined && allowance < ghoAmountForSwap;
  const minSwapOutput = useMemo(() => {
    if (!preview || !ghoAmountForSwap || preview.ghoAmount === 0n) return undefined;
    return (preview.estimatedOutput * ghoAmountForSwap) / preview.ghoAmount;
  }, [preview, ghoAmountForSwap]);

  const {
    approve, txHash: approveTxHash, status: approveStatus,
    error: approveError, reset: resetApprove,
  } = useApprove();

  const {
    redeem: swapFromGHO, txHash: swapTxHash, status: swapStatus,
    error: swapError, redeemEvent, dustEvents, reset: resetSwap,
  } = useRedeem();

  const {
    redeemShares, txHash: redeemSharesTxHash, status: redeemSharesStatus,
    error: redeemSharesError, reset: resetRedeemShares,
  } = useRedeemShares();

  useEffect(() => {
    if (redeemSharesStatus === "success") {
      refetchBalances();
    }
  }, [redeemSharesStatus, refetchBalances]);

  useEffect(() => {
    if (redeemSharesStatus === "success" && preRedeemGhoBalance !== undefined) {
      const delta = balances.GHO > preRedeemGhoBalance ? balances.GHO - preRedeemGhoBalance : 0n;
      if (delta > 0n) setRedeemedGhoAmount(delta);
    }
  }, [redeemSharesStatus, preRedeemGhoBalance, balances.GHO]);

  useEffect(() => {
    if (approveStatus === "success") refetchAllowance();
  }, [approveStatus, refetchAllowance]);

  useEffect(() => {
    if (swapStatus === "success") {
      refetchBalances();
      refetchAllowance();
      if (swapTxHash) {
        trackEvent({
          type: "redeem_completed",
          token: outputToken,
          amountOut: redeemEvent?.outputAmount?.toString() ?? "0",
          txHash: swapTxHash,
        });
      }
    }
  }, [swapStatus, refetchBalances, refetchAllowance, swapTxHash, outputToken, redeemEvent]);

  const steps: TransactionStep[] = useMemo(() => {
    const result: TransactionStep[] = [];
    if (redeemSharesStatus !== "idle") {
      result.push({
        label: isGHOOutput ? "Redeem to GHO" : "Redeem sGHO to GHO",
        status: redeemSharesStatus,
        txHash: redeemSharesTxHash,
        error: redeemSharesError?.message,
      });
    }

    if (!isGHOOutput && redeemSharesStatus === "success") {
      if (needsApproval || approveStatus !== "idle") {
        result.push({
          label: "Approve GHO",
          status: approveStatus,
          txHash: approveTxHash,
          error: approveError?.message,
        });
      }

      result.push({
        label: `Swap GHO to ${outputToken}`,
        status: swapStatus,
        txHash: swapTxHash,
        error: swapError?.message,
      });
    }

    return result;
  }, [
    redeemSharesStatus,
    redeemSharesTxHash,
    redeemSharesError,
    isGHOOutput,
    needsApproval,
    approveStatus,
    approveTxHash,
    approveError,
    outputToken,
    swapStatus,
    swapTxHash,
    swapError,
  ]);

  const isInProgress =
    ["pending", "confirming"].includes(redeemSharesStatus) ||
    ["pending", "confirming"].includes(approveStatus) ||
    ["pending", "confirming"].includes(swapStatus);
  const awaitingApprovalAction =
    !isGHOOutput && redeemSharesStatus === "success" && needsApproval && approveStatus === "idle";
  const awaitingSwapAction =
    !isGHOOutput &&
    redeemSharesStatus === "success" &&
    (!needsApproval || approveStatus === "success") &&
    swapStatus === "idle";

  const handleSubmit = useCallback(() => {
    if (!parsedShares || !validation.valid || !preview) return;

    if (redeemSharesStatus === "idle") {
      setPreRedeemGhoBalance(balances.GHO);
      setRedeemedGhoAmount(undefined);
      redeemShares(parsedShares);
      return;
    }

    if (!isGHOOutput && ghoAmountForSwap && ghoAmountForSwap > 0n && minSwapOutput !== undefined) {
      if (needsApproval && approveStatus === "idle") {
        approve(addresses.GHO, ghoAmountForSwap, outputToken);
      } else if ((!needsApproval || approveStatus === "success") && swapStatus === "idle") {
        swapFromGHO(ghoAmountForSwap, token.address, minSwapOutput, outputToken);
      }
    }
  }, [
    parsedShares,
    validation.valid,
    preview,
    redeemSharesStatus,
    balances.GHO,
    isGHOOutput,
    ghoAmountForSwap,
    minSwapOutput,
    needsApproval,
    approveStatus,
    approve,
    outputToken,
    swapStatus,
    swapFromGHO,
    token.address,
    redeemShares,
  ]);

  const handleReset = () => {
    resetApprove();
    resetSwap();
    resetRedeemShares();
    setSharesStr("");
    setPreRedeemGhoBalance(undefined);
    setRedeemedGhoAmount(undefined);
  };

  let buttonLabel = "Enter shares amount";
  let buttonDisabled = true;
  if (!sharesStr) { buttonLabel = "Enter shares amount"; }
  else if (!validation.valid) { buttonLabel = validation.error ?? "Invalid input"; }
  else if (previewLoading) { buttonLabel = "Fetching quote..."; }
  else if (isInProgress) { buttonLabel = "Processing..."; }
  else if (redeemSharesStatus === "idle") { buttonLabel = isGHOOutput ? "Redeem" : "Redeem to GHO"; buttonDisabled = false; }
  else if (awaitingApprovalAction) { buttonLabel = "Approve GHO"; buttonDisabled = false; }
  else if (awaitingSwapAction) { buttonLabel = `Swap to ${outputToken}`; buttonDisabled = false; }

  const showStepper = redeemSharesStatus !== "idle" || approveStatus !== "idle" || swapStatus !== "idle";
  const showActionButton = !showStepper || awaitingApprovalAction || awaitingSwapAction;
  const outputDecimals = outputToken === "GHO" ? 18 : 6;
  const showSuccess =
    (isGHOOutput && redeemSharesStatus === "success") ||
    (!isGHOOutput && swapStatus === "success" && !!redeemEvent);
  const successAmount = isGHOOutput
    ? (redeemedGhoAmount ?? preview?.ghoAmount ?? 0n)
    : (redeemEvent?.outputAmount ?? 0n);
  const rootError = redeemSharesError ?? approveError ?? swapError;

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
            resetSwap();
            resetRedeemShares();
            setPreRedeemGhoBalance(undefined);
            setRedeemedGhoAmount(undefined);
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
            resetSwap();
            resetRedeemShares();
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

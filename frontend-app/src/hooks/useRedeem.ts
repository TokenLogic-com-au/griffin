"use client";

import {
  useWriteContract,
  useWaitForTransactionReceipt,
  useWatchContractEvent,
} from "wagmi";
import { useCallback, useState } from "react";
import { sGHORouterAbi } from "@/abi/sGHORouter";
import { addresses } from "@/config/addresses";
import { targetChain } from "@/config/chains";
import { parseError } from "@/lib/errors";
import { trackEvent } from "@/lib/analytics";
import type { Address } from "viem";
import type { StepStatus, SupportedToken } from "@/types";

interface RedeemEvent {
  user: Address;
  outputToken: Address;
  sharesRedeemed: bigint;
  outputAmount: bigint;
}

interface DustEvent {
  user: Address;
  token: Address;
  amount: bigint;
}

/**
 * Hook for executing sGHORouter.redeem().
 * Tracks full tx lifecycle and watches for Redeemed + DustReturned events.
 */
export function useRedeem() {
  const [redeemEvent, setRedeemEvent] = useState<RedeemEvent | null>(null);
  const [dustEvents, setDustEvents] = useState<DustEvent[]>([]);

  const {
    data: txHash,
    writeContract,
    isPending: isWritePending,
    isError: isWriteError,
    error: writeError,
    reset: resetWrite,
  } = useWriteContract();

  const {
    isLoading: isConfirming,
    isSuccess: isConfirmed,
    isError: isReceiptError,
    error: receiptError,
  } = useWaitForTransactionReceipt({
    hash: txHash,
    chainId: targetChain.id,
  });

  // Watch for Redeemed event
  useWatchContractEvent({
    chainId: targetChain.id,
    address: addresses.sGHORouter,
    abi: sGHORouterAbi,
    eventName: "Redeemed",
    onLogs(logs) {
      for (const log of logs) {
        if (log.transactionHash === txHash) {
          const args = log.args as unknown as RedeemEvent;
          setRedeemEvent(args);
        }
      }
    },
    enabled: !!txHash && !isConfirmed,
  });

  // Watch for DustReturned event
  useWatchContractEvent({
    chainId: targetChain.id,
    address: addresses.sGHORouter,
    abi: sGHORouterAbi,
    eventName: "DustReturned",
    onLogs(logs) {
      for (const log of logs) {
        if (log.transactionHash === txHash) {
          const args = log.args as unknown as DustEvent;
          setDustEvents((prev) => [...prev, args]);
        }
      }
    },
    enabled: !!txHash && !isConfirmed,
  });

  const redeem = useCallback(
    (
      shares: bigint,
      tokenAddress: Address,
      minOutputAmount: bigint,
      tokenSymbol: SupportedToken
    ) => {
      setRedeemEvent(null);
      setDustEvents([]);

      trackEvent({ type: "redeem_started", token: tokenSymbol, shares: shares.toString() });

      writeContract({
        chainId: targetChain.id,
        address: addresses.sGHORouter,
        abi: sGHORouterAbi,
        functionName: "redeem",
        args: [shares, tokenAddress, minOutputAmount],
      });
    },
    [writeContract]
  );

  let status: StepStatus = "idle";
  if (isWritePending) status = "pending";
  else if (isConfirming) status = "confirming";
  else if (isConfirmed) status = "success";
  else if (isWriteError || isReceiptError) status = "error";

  const error = writeError || receiptError;

  const reset = useCallback(() => {
    resetWrite();
    setRedeemEvent(null);
    setDustEvents([]);
  }, [resetWrite]);

  return {
    redeem,
    txHash,
    status,
    isLoading: isWritePending || isConfirming,
    isSuccess: isConfirmed,
    isError: isWriteError || isReceiptError,
    error: error ? parseError(error) : undefined,
    redeemEvent,
    dustEvents,
    reset,
  };
}

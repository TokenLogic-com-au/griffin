"use client";

import {
  useWriteContract,
  useWaitForTransactionReceipt,
  useWatchContractEvent,
} from "wagmi";
import { useCallback, useState } from "react";
import { gsmRouterAbi } from "@/abi/gsmRouter";
import { addresses } from "@/config/addresses";
import { targetChain } from "@/config/chains";
import { parseError } from "@/lib/errors";
import { trackEvent } from "@/lib/analytics";
import type { Address } from "viem";
import type { StepStatus, SupportedToken } from "@/types";

interface RedeemEvent {
  user: Address;
  outputToken: Address;
  ghoAmount: bigint;
  outputAmount: bigint;
}

interface DustEvent {
  user: Address;
  token: Address;
  amount: bigint;
}

/**
 * Hook for executing GSMRouter.swapFromGHO().
 * Tracks full tx lifecycle and watches for SwapFromGHO + DustReturned events.
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

  // Watch for SwapFromGHO event
  useWatchContractEvent({
    chainId: targetChain.id,
    address: addresses.gsmRouter,
    abi: gsmRouterAbi,
    eventName: "SwapFromGHO",
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
    address: addresses.gsmRouter,
    abi: gsmRouterAbi,
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
      ghoAmount: bigint,
      tokenAddress: Address,
      minOutputAmount: bigint,
      tokenSymbol: SupportedToken
    ) => {
      setRedeemEvent(null);
      setDustEvents([]);

      trackEvent({ type: "redeem_started", token: tokenSymbol, shares: ghoAmount.toString() });

      writeContract({
        chainId: targetChain.id,
        address: addresses.gsmRouter,
        abi: gsmRouterAbi,
        functionName: "swapFromGHO",
        args: [tokenAddress, ghoAmount, minOutputAmount],
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

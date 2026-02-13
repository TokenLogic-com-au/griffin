"use client";

import {
  useWriteContract,
  useWaitForTransactionReceipt,
  useWatchContractEvent,
} from "wagmi";
import { useCallback, useState } from "react";
import { sGHORouterAbi } from "@/abi/sGHORouter";
import { addresses } from "@/config/addresses";
import { parseError } from "@/lib/errors";
import { trackEvent } from "@/lib/analytics";
import type { Address } from "viem";
import type { StepStatus, SupportedToken } from "@/types";

interface DepositEvent {
  user: Address;
  inputToken: Address;
  inputAmount: bigint;
  ghoAmount: bigint;
  sharesReceived: bigint;
}

interface DustEvent {
  user: Address;
  token: Address;
  amount: bigint;
}

/**
 * Hook for executing sGHORouter.deposit().
 * Tracks full tx lifecycle and watches for Deposited + DustReturned events.
 */
export function useDeposit() {
  const [depositEvent, setDepositEvent] = useState<DepositEvent | null>(null);
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
  });

  // Watch for Deposited event
  useWatchContractEvent({
    address: addresses.sGHORouter,
    abi: sGHORouterAbi,
    eventName: "Deposited",
    onLogs(logs) {
      for (const log of logs) {
        if (log.transactionHash === txHash) {
          const args = log.args as unknown as DepositEvent;
          setDepositEvent(args);
        }
      }
    },
    enabled: !!txHash && !isConfirmed,
  });

  // Watch for DustReturned event
  useWatchContractEvent({
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

  const deposit = useCallback(
    (
      tokenAddress: Address,
      amount: bigint,
      minOutputAmount: bigint,
      tokenSymbol: SupportedToken
    ) => {
      setDepositEvent(null);
      setDustEvents([]);

      trackEvent({ type: "deposit_started", token: tokenSymbol, amount: amount.toString() });

      writeContract({
        address: addresses.sGHORouter,
        abi: sGHORouterAbi,
        functionName: "deposit",
        args: [tokenAddress, amount, minOutputAmount],
      });
    },
    [writeContract]
  );

  // Track completion / failure
  if (isConfirmed && txHash) {
    // Event-based tracking handled via depositEvent
  }

  let status: StepStatus = "idle";
  if (isWritePending) status = "pending";
  else if (isConfirming) status = "confirming";
  else if (isConfirmed) status = "success";
  else if (isWriteError || isReceiptError) status = "error";

  const error = writeError || receiptError;

  const reset = useCallback(() => {
    resetWrite();
    setDepositEvent(null);
    setDustEvents([]);
  }, [resetWrite]);

  return {
    deposit,
    txHash,
    status,
    isLoading: isWritePending || isConfirming,
    isSuccess: isConfirmed,
    isError: isWriteError || isReceiptError,
    error: error ? parseError(error) : undefined,
    depositEvent,
    dustEvents,
    reset,
  };
}

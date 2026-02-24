"use client";

import { useCallback } from "react";
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from "wagmi";
import { erc4626Abi } from "@/abi/erc4626";
import { addresses } from "@/config/addresses";
import { targetChain } from "@/config/chains";
import { parseError } from "@/lib/errors";
import type { StepStatus } from "@/types";

/**
 * Hook for executing sGHO.redeem(shares, receiver, owner).
 */
export function useRedeemShares() {
  const { address: account } = useAccount();
  const {
    data: txHash,
    writeContract,
    isPending: isWritePending,
    isError: isWriteError,
    error: writeError,
    reset,
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

  const redeemShares = useCallback(
    (shares: bigint) => {
      if (!account) return;
      writeContract({
        chainId: targetChain.id,
        address: addresses.sGHO,
        abi: erc4626Abi,
        functionName: "redeem",
        args: [shares, account, account],
      });
    },
    [account, writeContract]
  );

  let status: StepStatus = "idle";
  if (isWritePending) status = "pending";
  else if (isConfirming) status = "confirming";
  else if (isConfirmed) status = "success";
  else if (isWriteError || isReceiptError) status = "error";

  const error = writeError || receiptError;

  return {
    redeemShares,
    txHash,
    status,
    isLoading: isWritePending || isConfirming,
    isSuccess: isConfirmed,
    isError: isWriteError || isReceiptError,
    error: error ? parseError(error) : undefined,
    reset,
  };
}

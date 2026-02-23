"use client";

import { useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { erc20Abi } from "@/abi/erc20";
import { addresses } from "@/config/addresses";
import { targetChain } from "@/config/chains";
import { parseError } from "@/lib/errors";
import { trackEvent } from "@/lib/analytics";
import type { Address } from "viem";
import type { StepStatus, SupportedToken } from "@/types";

/**
 * Hook to approve ERC20 token spending by sGHORouter.
 * Tracks tx lifecycle: idle -> pending -> confirming -> success/error.
 */
export function useApprove() {
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

  const approve = async (tokenAddress: Address, amount: bigint, tokenSymbol?: SupportedToken) => {
    try {
      writeContract({
        chainId: targetChain.id,
        address: tokenAddress,
        abi: erc20Abi,
        functionName: "approve",
        args: [addresses.sGHORouter, amount],
      });
    } catch (error) {
      const parsed = parseError(error);
      if (parsed.isUserRejection && tokenSymbol) {
        trackEvent({ type: "approval_rejected", token: tokenSymbol });
      }
      throw error;
    }
  };

  // Derive step status
  let status: StepStatus = "idle";
  if (isWritePending) status = "pending";
  else if (isConfirming) status = "confirming";
  else if (isConfirmed) status = "success";
  else if (isWriteError || isReceiptError) status = "error";

  const error = writeError || receiptError;

  return {
    approve,
    txHash,
    status,
    isLoading: isWritePending || isConfirming,
    isSuccess: isConfirmed,
    isError: isWriteError || isReceiptError,
    error: error ? parseError(error) : undefined,
    reset,
  };
}

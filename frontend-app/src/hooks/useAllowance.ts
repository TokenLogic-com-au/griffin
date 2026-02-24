"use client";

import { useReadContract, useAccount } from "wagmi";
import { erc20Abi } from "@/abi/erc20";
import { addresses } from "@/config/addresses";
import type { Address } from "viem";

/**
 * Read the ERC20 allowance for `tokenAddress` granted to the router
 * by the connected wallet.
 */
export function useAllowance(tokenAddress: Address | undefined) {
  const { address: account } = useAccount();

  const { data, isLoading, isError, refetch } = useReadContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: "allowance",
    args: account ? [account, addresses.gsmRouter] : undefined,
    query: {
      enabled: !!account && !!tokenAddress,
      refetchInterval: 10_000,
    },
  });

  return {
    allowance: (data as bigint) ?? 0n,
    isLoading,
    isError,
    refetch,
  };
}

/**
 * Read the sGHO allowance granted to the router for redeem operations.
 * sGHO uses ERC4626 which inherits ERC20 approval.
 */
export function useSGHOAllowance() {
  return useAllowance(addresses.sGHO);
}

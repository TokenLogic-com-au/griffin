"use client";

import { useMemo } from "react";
import { useReadContract } from "wagmi";
import type { Address } from "viem";
import { ghoAbi } from "@/abi/gho";
import { addresses, getGsmForToken } from "@/config/addresses";

/**
 * Read current GHO facilitator bucket headroom for the GSM that corresponds to a token.
 * For non-GSM tokens (e.g. direct GHO input), returns undefined headroom.
 */
export function useFacilitatorHeadroom(tokenAddress: Address | undefined) {
  const facilitatorAddress = useMemo(() => {
    if (!tokenAddress || tokenAddress === addresses.GHO) return undefined;
    try {
      return getGsmForToken(tokenAddress);
    } catch {
      return undefined;
    }
  }, [tokenAddress]);

  const { data, isLoading, isError, refetch } = useReadContract({
    address: addresses.GHO,
    abi: ghoAbi,
    functionName: "getFacilitatorBucket",
    args: facilitatorAddress ? [facilitatorAddress] : undefined,
    query: {
      enabled: !!facilitatorAddress,
      refetchInterval: 10_000,
    },
  });

  const bucketCapacity = data ? BigInt((data as readonly [bigint, bigint])[0]) : undefined;
  const bucketLevel = data ? BigInt((data as readonly [bigint, bigint])[1]) : undefined;
  const headroom =
    bucketCapacity !== undefined && bucketLevel !== undefined
      ? bucketCapacity > bucketLevel
        ? bucketCapacity - bucketLevel
        : 0n
      : undefined;

  return {
    facilitatorAddress,
    bucketCapacity,
    bucketLevel,
    headroom,
    isLoading,
    isError,
    refetch,
  };
}

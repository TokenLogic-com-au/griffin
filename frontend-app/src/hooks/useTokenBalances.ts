"use client";

import { useReadContracts, useAccount } from "wagmi";
import { erc20Abi } from "@/abi/erc20";
import { erc4626Abi } from "@/abi/erc4626";
import { addresses } from "@/config/addresses";

export interface TokenBalances {
  GHO: bigint;
  USDC: bigint;
  USDT: bigint;
  sGHO: bigint;
}

const ZERO_BALANCES: TokenBalances = {
  GHO: 0n,
  USDC: 0n,
  USDT: 0n,
  sGHO: 0n,
};

/**
 * Read GHO, USDC, USDT, and sGHO balances for the connected wallet.
 * Uses multicall for a single RPC round-trip.
 */
export function useTokenBalances() {
  const { address: account } = useAccount();

  const { data, isLoading, isError, refetch } = useReadContracts({
    contracts: account
      ? [
          {
            address: addresses.GHO,
            abi: erc20Abi,
            functionName: "balanceOf",
            args: [account],
          },
          {
            address: addresses.USDC,
            abi: erc20Abi,
            functionName: "balanceOf",
            args: [account],
          },
          {
            address: addresses.USDT,
            abi: erc20Abi,
            functionName: "balanceOf",
            args: [account],
          },
          {
            address: addresses.sGHO,
            abi: erc4626Abi,
            functionName: "balanceOf",
            args: [account],
          },
        ]
      : [],
    query: {
      enabled: !!account,
      refetchInterval: 15_000, // refresh every 15s
    },
  });

  const balances: TokenBalances = data
    ? {
        GHO: (data[0]?.result as bigint) ?? 0n,
        USDC: (data[1]?.result as bigint) ?? 0n,
        USDT: (data[2]?.result as bigint) ?? 0n,
        sGHO: (data[3]?.result as bigint) ?? 0n,
      }
    : ZERO_BALANCES;

  return { balances, isLoading, isError, refetch };
}

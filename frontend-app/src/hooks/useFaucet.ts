"use client";

import { useState, useCallback } from "react";
import { useAccount } from "wagmi";
import {
  type FaucetResult,
  type FaucetToken,
} from "@/lib/faucet";
import { useTokenBalances } from "./useTokenBalances";

type FaucetStatus = "idle" | "dripping" | "done" | "error";

export function useFaucet() {
  const { address } = useAccount();
  const { refetch: refetchBalances } = useTokenBalances();
  const [status, setStatus] = useState<FaucetStatus>("idle");
  const [results, setResults] = useState<FaucetResult[]>([]);
  const [currentToken, setCurrentToken] = useState<FaucetToken | "all" | null>(null);

  const dripViaApi = useCallback(async (token: FaucetToken | "all"): Promise<FaucetResult[]> => {
    if (!address) return [];

    const response = await fetch("/api/faucet", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        token,
        recipient: address,
      }),
    });

    const data = await response.json().catch(() => null);
    if (!response.ok) {
      const errorMessage =
        data && typeof data.error === "string"
          ? data.error
          : `Faucet request failed (${response.status}).`;
      throw new Error(errorMessage);
    }

    if (!data || !Array.isArray(data.results)) {
      throw new Error("Invalid faucet response.");
    }

    return data.results as FaucetResult[];
  }, [address]);

  const drip = useCallback(
    async (token: FaucetToken | "all") => {
      if (!address) return;

      setStatus("dripping");
      setResults([]);
      setCurrentToken(token);

      try {
        const res = await dripViaApi(token);

        setResults(res);
        setStatus(res.every((r) => r.success) ? "done" : "error");

        // Refresh balances after drip
        setTimeout(() => refetchBalances(), 1000);
      } catch (e) {
        setResults([{ token: token === "all" ? "ETH" : token, success: false, error: String(e) }]);
        setStatus("error");
      }
    },
    [address, dripViaApi, refetchBalances]
  );

  const reset = useCallback(() => {
    setStatus("idle");
    setResults([]);
    setCurrentToken(null);
  }, []);

  return {
    drip,
    status,
    results,
    currentToken,
    reset,
    isAvailable: !!address,
  };
}

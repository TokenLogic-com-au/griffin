"use client";

import { useAccount, useSwitchChain } from "wagmi";
import { targetChain } from "@/config/chains";
import { useMounted } from "./useMounted";

/**
 * Guard hook: checks if the connected wallet is on the correct chain.
 * Guarded with useMounted to prevent SSR hydration mismatch.
 */
export function useNetworkGuard() {
  const mounted = useMounted();
  const { chain, isConnected } = useAccount();
  const { switchChain, isPending: isSwitching } = useSwitchChain();

  // Don't show wrong-network state until client has hydrated
  const ready = mounted && isConnected;
  const isCorrectNetwork = !ready || chain?.id === targetChain.id;
  const needsSwitch = ready && !isCorrectNetwork;
  const canSwitch = typeof switchChain === "function";

  const switchToCorrectNetwork = () => {
    if (canSwitch) {
      switchChain({ chainId: targetChain.id });
    }
  };

  return {
    isCorrectNetwork,
    needsSwitch,
    isSwitching,
    currentChainName: chain?.name ?? "Unknown",
    targetChainName: targetChain.name,
    targetChainId: targetChain.id,
    canSwitch,
    switchToCorrectNetwork,
  };
}

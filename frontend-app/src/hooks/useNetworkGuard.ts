"use client";

import { useAccount, useSwitchChain } from "wagmi";
import { isTenderlyVirtualTestNet, targetChain } from "@/config/chains";
import { useMounted } from "./useMounted";

type Eip1193Provider = {
  request: (args: { method: string; params?: unknown[] }) => Promise<unknown>;
};

type WalletAddChainParams = {
  chainId: string;
  chainName: string;
  nativeCurrency: {
    name: string;
    symbol: string;
    decimals: number;
  };
  rpcUrls: string[];
  blockExplorerUrls?: string[];
};

function getRpcUrlForWalletAdd(): string | undefined {
  const defaultRpc = targetChain.rpcUrls.default.http[0];
  if (defaultRpc) return defaultRpc;

  const publicRpc = targetChain.rpcUrls.public?.http[0];
  return publicRpc;
}

function toWalletAddParams(): WalletAddChainParams | null {
  const rpcUrl = getRpcUrlForWalletAdd();
  if (!rpcUrl) return null;

  const explorerUrl = targetChain.blockExplorers?.default.url;
  return {
    chainId: `0x${targetChain.id.toString(16)}`,
    chainName: targetChain.name,
    nativeCurrency: {
      name: targetChain.nativeCurrency.name,
      symbol: targetChain.nativeCurrency.symbol,
      decimals: targetChain.nativeCurrency.decimals,
    },
    rpcUrls: [rpcUrl],
    blockExplorerUrls: explorerUrl ? [explorerUrl] : undefined,
  };
}

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

  const switchToCorrectNetwork = async () => {
    if (canSwitch) {
      if (isTenderlyVirtualTestNet && typeof window !== "undefined") {
        const provider = (window as Window & { ethereum?: Eip1193Provider }).ethereum;
        const addParams = toWalletAddParams();

        if (provider && addParams) {
          try {
            await provider.request({
              method: "wallet_addEthereumChain",
              params: [addParams],
            });
          } catch {
            // Continue to switchChain below; some wallets may already know the chain.
          }
        }
      }

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

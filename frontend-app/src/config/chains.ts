import { mainnet, hardhat } from "wagmi/chains";
import { http, type Chain } from "viem";

const chainId = parseInt(process.env.NEXT_PUBLIC_CHAIN_ID || "1", 10);

/** Determine the target chain based on env */
export const targetChain: Chain = chainId === 31337 ? hardhat : mainnet;

/** Build the transport for the target chain */
export function getTransport() {
  if (chainId === 31337) {
    const anvilUrl = process.env.NEXT_PUBLIC_ANVIL_RPC_URL || "http://127.0.0.1:8545";
    return http(anvilUrl);
  }
  // For mainnet, use default public RPCs via wagmi
  return http();
}

/** Supported chain IDs */
export const supportedChainIds = [1, 31337] as const;

/** Check if a chain ID is supported */
export function isSupportedChain(id: number): boolean {
  return (supportedChainIds as readonly number[]).includes(id);
}

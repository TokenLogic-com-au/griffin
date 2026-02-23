import { defineChain, http, type Chain } from "viem";
import { mainnet, hardhat } from "wagmi/chains";

const parsedChainId = Number.parseInt(process.env.NEXT_PUBLIC_CHAIN_ID || "1", 10);
const chainId = Number.isFinite(parsedChainId) ? parsedChainId : 1;

const anvilRpcUrl = process.env.NEXT_PUBLIC_ANVIL_RPC_URL || "http://127.0.0.1:8545";
const tenderlyRpcUrl = process.env.NEXT_PUBLIC_TENDERLY_RPC_URL?.trim() || "";
const tenderlyEnabledFlag = process.env.NEXT_PUBLIC_TENDERLY_VNET_ENABLED === "true";

export const isTenderlyVirtualTestNet = tenderlyEnabledFlag || tenderlyRpcUrl.length > 0;
export const isInvalidTenderlyChainId = isTenderlyVirtualTestNet && chainId === 1;
export const isAnvilLocalFork = !isTenderlyVirtualTestNet && chainId === 31337;
export const isDevForkChain = isTenderlyVirtualTestNet || isAnvilLocalFork;

if (isInvalidTenderlyChainId) {
  throw new Error(
    "Invalid Tenderly configuration: NEXT_PUBLIC_CHAIN_ID=1 is not allowed in Tenderly mode. " +
      "Use a Tenderly Virtual TestNet with a non-1 chain ID."
  );
}

function buildTenderlyChain(): Chain {
  const rpcUrl = tenderlyRpcUrl || anvilRpcUrl;
  const name = process.env.NEXT_PUBLIC_TENDERLY_CHAIN_NAME?.trim() || "Tenderly Virtual TestNet";
  const explorerUrl = process.env.NEXT_PUBLIC_TENDERLY_EXPLORER_URL?.trim();
  const nativeCurrencyName = process.env.NEXT_PUBLIC_TENDERLY_NATIVE_CURRENCY_NAME?.trim() || "Ether";
  const nativeCurrencySymbol = process.env.NEXT_PUBLIC_TENDERLY_NATIVE_CURRENCY_SYMBOL?.trim() || "ETH";

  return defineChain({
    id: chainId,
    name,
    nativeCurrency: {
      name: nativeCurrencyName,
      symbol: nativeCurrencySymbol,
      decimals: 18,
    },
    rpcUrls: {
      default: { http: [rpcUrl] },
      public: { http: [rpcUrl] },
    },
    blockExplorers: explorerUrl
      ? {
          default: {
            name: "Tenderly Explorer",
            url: explorerUrl,
          },
        }
      : undefined,
    testnet: true,
  });
}

/** Determine the target chain based on env */
export const targetChain: Chain = isTenderlyVirtualTestNet
  ? buildTenderlyChain()
  : chainId === 31337
    ? hardhat
    : mainnet;

/** Build the transport for the target chain */
export function getTransport() {
  if (isTenderlyVirtualTestNet) {
    return http(tenderlyRpcUrl || anvilRpcUrl);
  }

  if (chainId === 31337) {
    return http(anvilRpcUrl);
  }

  // For mainnet, use default public RPCs via wagmi
  return http();
}

/** Supported chain IDs */
export const supportedChainIds: readonly number[] = [targetChain.id];

/** Check if a chain ID is supported */
export function isSupportedChain(id: number): boolean {
  return supportedChainIds.includes(id);
}

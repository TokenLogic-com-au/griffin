import type { Address } from "viem";
import type { TokenInfo, SupportedToken } from "@/types";
import { addresses } from "./addresses";

export const TOKENS: Record<SupportedToken, TokenInfo> = {
  GHO: {
    symbol: "GHO",
    name: "GHO Stablecoin",
    address: addresses.GHO,
    decimals: 18,
    icon: "/tokens/gho.svg",
  },
  USDC: {
    symbol: "USDC",
    name: "USD Coin",
    address: addresses.USDC,
    decimals: 6,
    icon: "/tokens/usdc.svg",
  },
  USDT: {
    symbol: "USDT",
    name: "Tether USD",
    address: addresses.USDT,
    decimals: 6,
    icon: "/tokens/usdt.svg",
  },
};

export const TOKEN_LIST: TokenInfo[] = [TOKENS.GHO, TOKENS.USDC, TOKENS.USDT];

/** Look up token info by address */
export function getTokenByAddress(address: Address): TokenInfo | undefined {
  return TOKEN_LIST.find(
    (t) => t.address.toLowerCase() === address.toLowerCase()
  );
}

/** Look up token info by symbol */
export function getTokenBySymbol(symbol: SupportedToken): TokenInfo {
  return TOKENS[symbol];
}

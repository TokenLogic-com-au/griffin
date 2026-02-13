import type { Address } from "viem";

function envAddress(key: string, fallback: Address): Address {
  const val = process.env[key];
  if (val && /^0x[0-9a-fA-F]{40}$/.test(val)) return val as Address;
  return fallback;
}

/** All contract addresses, env-overridable for dev/fork usage */
export const addresses = {
  sGHORouter: envAddress(
    "NEXT_PUBLIC_SGHO_ROUTER_ADDRESS",
    "0x0000000000000000000000000000000000000000" as Address
  ),
  gsmRouter: envAddress(
    "NEXT_PUBLIC_GSM_ROUTER_ADDRESS",
    "0x0000000000000000000000000000000000000000" as Address
  ),
  sGHO: envAddress(
    "NEXT_PUBLIC_SGHO_ADDRESS",
    "0x0000000000000000000000000000000000000000" as Address
  ),
  GHO: envAddress(
    "NEXT_PUBLIC_GHO_ADDRESS",
    "0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f" as Address
  ),
  USDC: envAddress(
    "NEXT_PUBLIC_USDC_ADDRESS",
    "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" as Address
  ),
  USDT: envAddress(
    "NEXT_PUBLIC_USDT_ADDRESS",
    "0xdAC17F958D2ee523a2206206994597C13D831ec7" as Address
  ),
  gsmUSDC: envAddress(
    "NEXT_PUBLIC_GSM_USDC_ADDRESS",
    "0xFeeb6FE430B7523fEF2a38327241eE7153779535" as Address
  ),
  gsmUSDT: envAddress(
    "NEXT_PUBLIC_GSM_USDT_ADDRESS",
    "0x535b2f7C20B9C83d70e519cf9991578eF9816B7B" as Address
  ),
} as const;

/** Get the GSM address for a given token address */
export function getGsmForToken(tokenAddress: Address): Address {
  if (tokenAddress === addresses.USDC) return addresses.gsmUSDC;
  if (tokenAddress === addresses.USDT) return addresses.gsmUSDT;
  throw new Error(`No GSM configured for token ${tokenAddress}`);
}

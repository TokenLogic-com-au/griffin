import type { Address } from "viem";

const RAW_ENV = {
  NEXT_PUBLIC_GSM_ROUTER_ADDRESS: process.env.NEXT_PUBLIC_GSM_ROUTER_ADDRESS,
  NEXT_PUBLIC_SGHO_ADDRESS: process.env.NEXT_PUBLIC_SGHO_ADDRESS,
  NEXT_PUBLIC_GHO_ADDRESS: process.env.NEXT_PUBLIC_GHO_ADDRESS,
  NEXT_PUBLIC_USDC_ADDRESS: process.env.NEXT_PUBLIC_USDC_ADDRESS,
  NEXT_PUBLIC_USDT_ADDRESS: process.env.NEXT_PUBLIC_USDT_ADDRESS,
  NEXT_PUBLIC_GSM_USDC_ADDRESS: process.env.NEXT_PUBLIC_GSM_USDC_ADDRESS,
  NEXT_PUBLIC_GSM_USDT_ADDRESS: process.env.NEXT_PUBLIC_GSM_USDT_ADDRESS,
} as const;

function normalizeAddress(value: string | undefined): string | undefined {
  if (!value) return undefined;
  const trimmed = value.trim();
  if (!trimmed) return undefined;
  if (
    (trimmed.startsWith("\"") && trimmed.endsWith("\"")) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1).trim();
  }
  return trimmed;
}

function envAddress(
  key: keyof typeof RAW_ENV,
  fallback: Address,
  required = false
): Address {
  const val = normalizeAddress(RAW_ENV[key]);
  if (val && /^0x[0-9a-fA-F]{40}$/.test(val)) return val as Address;
  if (required) {
    throw new Error(
      `Missing or invalid ${key}. Set a 42-char 0x-prefixed address in your environment.`
    );
  }
  return fallback;
}

/** All contract addresses, env-overridable for dev/fork usage */
export const addresses = {
  gsmRouter: envAddress(
    "NEXT_PUBLIC_GSM_ROUTER_ADDRESS",
    "0x0000000000000000000000000000000000000000" as Address,
    true
  ),
  sGHO: envAddress(
    "NEXT_PUBLIC_SGHO_ADDRESS",
    "0x0000000000000000000000000000000000000000" as Address,
    true
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

import { parseUnits } from "viem";
import type { TokenInfo, SupportedToken } from "@/types";

const SUPPORTED_SYMBOLS: SupportedToken[] = ["GHO", "USDC", "USDT"];

export interface ValidationResult {
  valid: boolean;
  error?: string;
}

/**
 * Validate that a token symbol is supported.
 */
export function validateToken(symbol: string): ValidationResult {
  if (!SUPPORTED_SYMBOLS.includes(symbol as SupportedToken)) {
    return { valid: false, error: `Unsupported token: ${symbol}. Use GHO, USDC, or USDT.` };
  }
  return { valid: true };
}

/**
 * Validate a user-entered amount string.
 * Returns the parsed bigint amount if valid.
 */
export function validateAmount(
  amountStr: string,
  token: TokenInfo,
  balance?: bigint
): ValidationResult & { amount?: bigint } {
  if (!amountStr || amountStr.trim() === "") {
    return { valid: false, error: "Enter an amount." };
  }

  // Check for valid number format
  const num = Number(amountStr);
  if (isNaN(num) || num < 0) {
    return { valid: false, error: "Enter a valid positive number." };
  }

  if (num === 0) {
    return { valid: false, error: "Amount must be greater than zero." };
  }

  // Check decimal places
  const parts = amountStr.split(".");
  if (parts[1] && parts[1].length > token.decimals) {
    return {
      valid: false,
      error: `${token.symbol} supports at most ${token.decimals} decimal places.`,
    };
  }

  let amount: bigint;
  try {
    amount = parseUnits(amountStr, token.decimals);
  } catch {
    return { valid: false, error: "Invalid amount format." };
  }

  if (amount === 0n) {
    return { valid: false, error: "Amount must be greater than zero." };
  }

  // Check balance
  if (balance !== undefined && amount > balance) {
    return { valid: false, error: `Insufficient ${token.symbol} balance.` };
  }

  return { valid: true, amount };
}

/**
 * Validate shares input for redemption.
 */
export function validateShares(
  sharesStr: string,
  sharesBalance?: bigint
): ValidationResult & { shares?: bigint } {
  if (!sharesStr || sharesStr.trim() === "") {
    return { valid: false, error: "Enter shares amount." };
  }

  const num = Number(sharesStr);
  if (isNaN(num) || num < 0) {
    return { valid: false, error: "Enter a valid positive number." };
  }

  if (num === 0) {
    return { valid: false, error: "Shares must be greater than zero." };
  }

  // sGHO has 18 decimals (ERC4626 wrapping GHO)
  const parts = sharesStr.split(".");
  if (parts[1] && parts[1].length > 18) {
    return { valid: false, error: "Too many decimal places." };
  }

  let shares: bigint;
  try {
    shares = parseUnits(sharesStr, 18);
  } catch {
    return { valid: false, error: "Invalid shares format." };
  }

  if (shares === 0n) {
    return { valid: false, error: "Shares must be greater than zero." };
  }

  if (sharesBalance !== undefined && shares > sharesBalance) {
    return { valid: false, error: "Insufficient sGHO balance." };
  }

  return { valid: true, shares };
}

/**
 * Compute minOutputAmount applying slippage tolerance.
 * @param estimatedOutput The estimated output amount.
 * @param slippageBps Slippage tolerance in basis points (e.g. 50 = 0.5%).
 */
export function applySlippage(estimatedOutput: bigint, slippageBps: number): bigint {
  if (slippageBps < 0 || slippageBps > 10000) {
    throw new Error("Slippage must be between 0 and 10000 bps");
  }
  return estimatedOutput - (estimatedOutput * BigInt(slippageBps)) / 10000n;
}

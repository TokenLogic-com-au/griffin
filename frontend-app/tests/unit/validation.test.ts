import { describe, it, expect } from "vitest";
import { validateToken, validateAmount, validateShares, applySlippage, calculateSlippageBps } from "@/lib/validation";
import type { TokenInfo } from "@/types";

const USDC: TokenInfo = {
  symbol: "USDC",
  name: "USD Coin",
  address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  decimals: 6,
  icon: "",
};

const GHO: TokenInfo = {
  symbol: "GHO",
  name: "GHO",
  address: "0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f",
  decimals: 18,
  icon: "",
};

describe("validateToken", () => {
  it("accepts GHO, USDC, USDT", () => {
    expect(validateToken("GHO").valid).toBe(true);
    expect(validateToken("USDC").valid).toBe(true);
    expect(validateToken("USDT").valid).toBe(true);
  });

  it("rejects unsupported tokens", () => {
    const result = validateToken("DAI");
    expect(result.valid).toBe(false);
    expect(result.error).toContain("Unsupported");
  });
});

describe("validateAmount", () => {
  it("rejects empty string", () => {
    const result = validateAmount("", USDC);
    expect(result.valid).toBe(false);
  });

  it("rejects zero", () => {
    const result = validateAmount("0", USDC);
    expect(result.valid).toBe(false);
    expect(result.error).toContain("greater than zero");
  });

  it("rejects negative numbers", () => {
    const result = validateAmount("-5", USDC);
    expect(result.valid).toBe(false);
  });

  it("rejects non-numeric input", () => {
    const result = validateAmount("abc", USDC);
    expect(result.valid).toBe(false);
  });

  it("accepts valid USDC amount", () => {
    const result = validateAmount("100.5", USDC);
    expect(result.valid).toBe(true);
    expect(result.amount).toBe(100_500_000n);
  });

  it("accepts valid GHO amount with 18 decimals", () => {
    const result = validateAmount("1.5", GHO);
    expect(result.valid).toBe(true);
    expect(result.amount).toBe(1_500_000_000_000_000_000n);
  });

  it("rejects too many decimal places", () => {
    const result = validateAmount("1.1234567", USDC);
    expect(result.valid).toBe(false);
    expect(result.error).toContain("decimal places");
  });

  it("rejects amount exceeding balance", () => {
    const balance = 50_000_000n; // 50 USDC
    const result = validateAmount("100", USDC, balance);
    expect(result.valid).toBe(false);
    expect(result.error).toContain("Insufficient");
  });

  it("accepts amount within balance", () => {
    const balance = 200_000_000n; // 200 USDC
    const result = validateAmount("100", USDC, balance);
    expect(result.valid).toBe(true);
  });
});

describe("validateShares", () => {
  it("rejects empty string", () => {
    expect(validateShares("").valid).toBe(false);
  });

  it("rejects zero", () => {
    const result = validateShares("0");
    expect(result.valid).toBe(false);
  });

  it("accepts valid shares", () => {
    const result = validateShares("10.5");
    expect(result.valid).toBe(true);
    expect(result.shares).toBe(10_500_000_000_000_000_000n);
  });

  it("rejects shares exceeding balance", () => {
    const balance = 5_000_000_000_000_000_000n; // 5 sGHO
    const result = validateShares("10", balance);
    expect(result.valid).toBe(false);
    expect(result.error).toContain("Insufficient sGHO");
  });
});

describe("applySlippage", () => {
  it("applies 0.5% slippage (50 bps)", () => {
    const amount = 1000n * 10n ** 18n; // 1000 tokens
    const result = applySlippage(amount, 50);
    // 1000 - 0.5% = 995
    expect(result).toBe(995n * 10n ** 18n);
  });

  it("applies 1% slippage (100 bps)", () => {
    const amount = 10000n;
    const result = applySlippage(amount, 100);
    expect(result).toBe(9900n);
  });

  it("handles zero slippage", () => {
    const amount = 1000n;
    const result = applySlippage(amount, 0);
    expect(result).toBe(1000n);
  });

  it("throws on invalid slippage", () => {
    expect(() => applySlippage(1000n, -1)).toThrow();
    expect(() => applySlippage(1000n, 10001)).toThrow();
  });
});

describe("calculateSlippageBps", () => {
  it("returns 0 bps at parity", () => {
    expect(calculateSlippageBps(100_000n, 100_000n)).toBe(0);
  });

  it("returns 100 bps for 1% worse quote", () => {
    expect(calculateSlippageBps(100_000n, 99_000n)).toBe(100);
  });

  it("returns 0 when quote is better than expected", () => {
    expect(calculateSlippageBps(100_000n, 101_000n)).toBe(0);
  });
});

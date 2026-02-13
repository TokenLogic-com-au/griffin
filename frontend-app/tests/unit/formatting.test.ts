import { describe, it, expect } from "vitest";
import {
  formatTokenAmount,
  formatAddress,
  formatBps,
  formatFee,
  getTxUrl,
} from "@/lib/formatting";

describe("formatTokenAmount", () => {
  it("formats 18-decimal token amount", () => {
    const amount = 1_500_000_000_000_000_000n; // 1.5 tokens
    expect(formatTokenAmount(amount, 18)).toBe("1.5");
  });

  it("formats 6-decimal token amount", () => {
    const amount = 1_500_000n; // 1.5 USDC
    expect(formatTokenAmount(amount, 6)).toBe("1.5");
  });

  it("formats zero", () => {
    expect(formatTokenAmount(0n, 18)).toBe("0");
  });

  it("formats large amounts with commas", () => {
    const amount = 1_000_000_000_000n; // 1,000,000 USDC
    const result = formatTokenAmount(amount, 6);
    expect(result).toContain("1,000,000");
  });

  it("respects display decimals parameter", () => {
    const amount = 1_123_456_789_012_345_678n; // 1.123456789...
    const result = formatTokenAmount(amount, 18, 2);
    expect(result).toBe("1.12");
  });
});

describe("formatAddress", () => {
  it("truncates Ethereum address", () => {
    const addr = "0x1234567890abcdef1234567890abcdef12345678";
    expect(formatAddress(addr)).toBe("0x1234...5678");
  });

  it("handles short strings", () => {
    expect(formatAddress("0x")).toBe("0x");
  });
});

describe("formatBps", () => {
  it("formats 50 bps as 0.50%", () => {
    expect(formatBps(50)).toBe("0.50%");
  });

  it("formats 100 bps as 1.00%", () => {
    expect(formatBps(100)).toBe("1.00%");
  });
});

describe("formatFee", () => {
  it("formats zero fee", () => {
    expect(formatFee(0n, 18, "GHO")).toBe("0 GHO");
  });

  it("formats non-zero fee", () => {
    const fee = 500_000_000_000_000_000n; // 0.5 GHO
    const result = formatFee(fee, 18, "GHO");
    expect(result).toContain("0.5");
    expect(result).toContain("GHO");
  });
});

describe("getTxUrl", () => {
  it("returns Etherscan URL for mainnet", () => {
    const url = getTxUrl("0xabc123", 1);
    expect(url).toBe("https://etherscan.io/tx/0xabc123");
  });

  it("returns placeholder for non-mainnet", () => {
    const url = getTxUrl("0xabc123", 31337);
    expect(url).toContain("0xabc123");
  });
});

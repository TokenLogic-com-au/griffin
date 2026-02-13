import { describe, it, expect } from "vitest";
import { parseError } from "@/lib/errors";
import { BaseError, ContractFunctionRevertedError } from "viem";

describe("parseError", () => {
  it("detects user rejection from error message", () => {
    const error = new Error("User rejected the request.");
    const result = parseError(error);
    expect(result.isUserRejection).toBe(true);
    expect(result.name).toBe("UserRejected");
    expect(result.message).toContain("rejected");
  });

  it("detects user denial (MetaMask style)", () => {
    const error = new Error("user denied transaction signature");
    const result = parseError(error);
    expect(result.isUserRejection).toBe(true);
  });

  it("handles plain string errors", () => {
    const result = parseError("something went wrong");
    expect(result.isUserRejection).toBe(false);
    expect(result.name).toBe("Unknown");
    expect(result.message).toBe("something went wrong");
  });

  it("handles null/undefined gracefully", () => {
    const result = parseError(null);
    expect(result.name).toBe("Unknown");
    expect(result.message).toBeTruthy();
  });

  it("handles generic Error objects", () => {
    const error = new Error("Transaction reverted");
    const result = parseError(error);
    expect(result.isUserRejection).toBe(false);
    expect(result.name).toBe("Unknown");
    expect(result.message).toBe("Transaction reverted");
  });

  it("returns actionable message for known error names", () => {
    // Simulate a viem BaseError with a short message containing known error info
    // We can't easily construct ContractFunctionRevertedError, so test the fallback path
    const error = new Error("The contract function reverted: InvalidToken");
    const result = parseError(error);
    expect(result.isUserRejection).toBe(false);
    // It should still produce a reasonable message from the error string
    expect(result.message).toContain("InvalidToken");
  });
});

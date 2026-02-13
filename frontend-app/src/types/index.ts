import type { Address } from "viem";

/** Supported input/output tokens */
export type SupportedToken = "GHO" | "USDC" | "USDT";

/** Token metadata */
export interface TokenInfo {
  symbol: SupportedToken;
  name: string;
  address: Address;
  decimals: number;
  icon: string;
}

/** Transaction step status */
export type StepStatus = "idle" | "pending" | "confirming" | "success" | "error";

/** A step in the multi-step transaction flow */
export interface TransactionStep {
  label: string;
  status: StepStatus;
  txHash?: `0x${string}`;
  error?: string;
}

/** Deposit preview result */
export interface DepositPreview {
  ghoAmount: bigint;
  estimatedShares: bigint;
  fee: bigint;
  priceImpactBps: number;
}

/** Redeem preview result */
export interface RedeemPreview {
  ghoAmount: bigint;
  estimatedOutput: bigint;
  fee: bigint;
  priceImpactBps: number;
}

/** Analytics event types */
export type AnalyticsEvent =
  | { type: "deposit_started"; token: SupportedToken; amount: string }
  | { type: "deposit_approved"; token: SupportedToken }
  | { type: "deposit_completed"; token: SupportedToken; shares: string; txHash: string }
  | { type: "deposit_failed"; token: SupportedToken; reason: string }
  | { type: "redeem_started"; token: SupportedToken; shares: string }
  | { type: "redeem_approved"; token: SupportedToken }
  | { type: "redeem_completed"; token: SupportedToken; amountOut: string; txHash: string }
  | { type: "redeem_failed"; token: SupportedToken; reason: string }
  | { type: "approval_rejected"; token: SupportedToken }
  | { type: "network_switch_prompted" }
  | { type: "network_switch_completed" };

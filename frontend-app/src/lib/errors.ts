import { BaseError, ContractFunctionRevertedError } from "viem";
import { onboardingRouterAbi } from "@/abi/onboardingRouter";
import { gsmRouterAbi } from "@/abi/gsmRouter";

/**
 * Known custom error names from onboarding and GSM router contracts,
 * mapped to user-friendly messages.
 */
const ERROR_MESSAGES: Record<string, string> = {
  // Onboarding router errors
  ZeroAddress:
    "A required contract address is missing. The router may not be configured correctly.",
  InvalidToken:
    "The selected token is not supported by the router. Please choose GHO, USDC, or USDT.",
  InvalidAmount:
    "The amount must be greater than zero. Please enter a valid amount.",
  SlippageExceeded:
    "The transaction output was less than your minimum. Try increasing slippage tolerance or reducing the amount.",
  InvalidConfiguration:
    "The router contract is misconfigured. Please contact support.",
  // GSMRouter errors
  InvalidGsm:
    "The GHO Stability Module is not available for this token. Please try again later.",
  OwnableInvalidOwner:
    "The provided owner address is invalid.",
  OwnableUnauthorizedAccount:
    "Your wallet is not authorized for this action.",
  SafeERC20FailedOperation:
    "Token transfer or approval failed at the contract level.",
};

/** User-rejected transaction signatures */
const USER_REJECTED_PATTERNS = [
  "user rejected",
  "user denied",
  "rejected the request",
  "ACTION_REJECTED",
  "User rejected the request",
];

export interface ParsedError {
  /** The custom error name if identified, otherwise 'Unknown' */
  name: string;
  /** Human-readable message */
  message: string;
  /** Whether the user explicitly rejected the transaction */
  isUserRejection: boolean;
}

/**
 * Parse a contract/wallet error into a user-friendly format.
 * Handles viem ContractFunctionRevertedError, user rejections, and generic errors.
 */
export function parseError(error: unknown): ParsedError {
  // Check for user rejection first
  const errorString = String(error);
  if (
    USER_REJECTED_PATTERNS.some((p) =>
      errorString.toLowerCase().includes(p.toLowerCase())
    )
  ) {
    return {
      name: "UserRejected",
      message: "You rejected the transaction in your wallet.",
      isUserRejection: true,
    };
  }

  // Walk the viem error chain to find a ContractFunctionRevertedError
  if (error instanceof BaseError) {
    const revertError = error.walk(
      (e) => e instanceof ContractFunctionRevertedError
    );

    if (revertError instanceof ContractFunctionRevertedError) {
      const errorName = revertError.data?.errorName;
      if (errorName && ERROR_MESSAGES[errorName]) {
        return {
          name: errorName,
          message: ERROR_MESSAGES[errorName],
          isUserRejection: false,
        };
      }
      // Unknown contract error
      return {
        name: errorName || "UnknownContractError",
        message: revertError.shortMessage || "The transaction was reverted by the contract.",
        isUserRejection: false,
      };
    }

    // Generic viem error with a short message
    return {
      name: "TransactionError",
      message: error.shortMessage || error.message,
      isUserRejection: false,
    };
  }

  // Fallback
  const msg = error instanceof Error ? error.message : String(error);
  return {
    name: "Unknown",
    message: msg || "An unexpected error occurred.",
    isUserRejection: false,
  };
}

/**
 * Get the ABIs that contain known custom errors for decoding.
 */
export function getErrorAbis() {
  return [...onboardingRouterAbi, ...gsmRouterAbi];
}

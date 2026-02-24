"use client";

import { useReadContract } from "wagmi";
import { gsmRouterAbi } from "@/abi/gsmRouter";
import { erc4626Abi } from "@/abi/erc4626";
import { addresses } from "@/config/addresses";
import { calculateSlippageBps } from "@/lib/validation";
import type { Address } from "viem";
import type { RedeemPreview } from "@/types";

/**
 * Preview the redeem flow:
 *   - sGHO.previewRedeem(shares) -> ghoAmount
 *   - For GHO output: ghoAmount is the output
 *   - For USDC/USDT: GSMRouter.previewSwapFromGHO(ghoAmount) -> output token amount
 */
export function usePreviewRedeem(
  shares: bigint | undefined,
  outputTokenAddress: Address | undefined
) {
  const isGHO = outputTokenAddress === addresses.GHO;
  const enabled = !!shares && shares > 0n && !!outputTokenAddress;

  // Step 1: Preview sGHO redeem to get GHO amount
  const redeemPreview = useReadContract({
    address: addresses.sGHO,
    abi: erc4626Abi,
    functionName: "previewRedeem",
    args: shares ? [shares] : undefined,
    query: {
      enabled: enabled,
    },
  });

  const ghoAmount = (redeemPreview.data as bigint) ?? undefined;

  // Step 2: For non-GHO output, preview the GSM swap
  const gsmPreview = useReadContract({
    address: addresses.gsmRouter,
    abi: gsmRouterAbi,
    functionName: "previewSwapFromGHO",
    args: outputTokenAddress && ghoAmount ? [outputTokenAddress, ghoAmount] : undefined,
    query: {
      enabled: !isGHO && !!outputTokenAddress && !!ghoAmount && ghoAmount > 0n,
    },
  });

  const estimatedOutput: bigint | undefined = isGHO
    ? ghoAmount
    : gsmPreview.data
      ? (gsmPreview.data as [bigint, bigint])[0]
      : undefined;

  const fee: bigint = !isGHO && gsmPreview.data
    ? (gsmPreview.data as [bigint, bigint])[1]
    : 0n;

  // Compute quote slippage vs 1:1 baseline.
  let priceImpactBps = 0;
  if (ghoAmount && estimatedOutput && !isGHO && ghoAmount > 0n) {
    // ghoAmount is 18-dec, estimatedOutput is 6-dec
    // Normalize estimatedOutput to 18-dec for comparison
    const normalized = estimatedOutput * 10n ** 12n;
    priceImpactBps = calculateSlippageBps(ghoAmount, normalized);
  }

  const isLoading = redeemPreview.isLoading || gsmPreview.isLoading;
  const isError = redeemPreview.isError || gsmPreview.isError;

  const preview: RedeemPreview | undefined =
    ghoAmount !== undefined && estimatedOutput !== undefined
      ? { ghoAmount, estimatedOutput, fee, priceImpactBps }
      : undefined;

  return { preview, isLoading, isError };
}

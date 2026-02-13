"use client";

import { useReadContract } from "wagmi";
import { gsmRouterAbi } from "@/abi/gsmRouter";
import { erc4626Abi } from "@/abi/erc4626";
import { addresses, getGsmForToken } from "@/config/addresses";
import type { Address } from "viem";
import type { DepositPreview } from "@/types";

/**
 * Preview the deposit flow:
 *   - For GHO: just sGHO.previewDeposit(amount)
 *   - For USDC/USDT: GSMRouter.previewSwapToGHO -> sGHO.previewDeposit(ghoAmount)
 *
 * Returns estimated shares, GHO amount, fee, and price impact.
 */
export function usePreviewDeposit(
  tokenAddress: Address | undefined,
  amount: bigint | undefined
) {
  const isGHO = tokenAddress === addresses.GHO;
  const enabled = !!tokenAddress && !!amount && amount > 0n;

  // Step 1: For non-GHO tokens, preview the GSM swap to get GHO amount
  const gsmAddress = !isGHO && tokenAddress ? getGsmForToken(tokenAddress) : undefined;
  const gsmPreview = useReadContract({
    address: addresses.gsmRouter,
    abi: gsmRouterAbi,
    functionName: "previewSwapToGHO",
    args: gsmAddress && amount ? [gsmAddress, amount] : undefined,
    query: {
      enabled: enabled && !isGHO && !!gsmAddress,
    },
  });

  // The GHO amount: either the direct amount (for GHO) or from GSM preview
  const ghoAmount: bigint | undefined = isGHO
    ? amount
    : gsmPreview.data
      ? (gsmPreview.data as [bigint, bigint])[0]
      : undefined;

  const fee: bigint = !isGHO && gsmPreview.data
    ? (gsmPreview.data as [bigint, bigint])[1]
    : 0n;

  // Step 2: Preview sGHO deposit to get estimated shares
  const sharesPreview = useReadContract({
    address: addresses.sGHO,
    abi: erc4626Abi,
    functionName: "previewDeposit",
    args: ghoAmount ? [ghoAmount] : undefined,
    query: {
      enabled: !!ghoAmount && ghoAmount > 0n,
    },
  });

  const estimatedShares = (sharesPreview.data as bigint) ?? undefined;

  // Compute price impact (approximate: based on 1:1 expectation for stablecoins)
  let priceImpactBps = 0;
  if (amount && ghoAmount && !isGHO && amount > 0n) {
    // Compare: we put in `amount` (6-dec stablecoin) and get `ghoAmount` (18-dec GHO)
    // Normalize: amount * 10^12 should equal ghoAmount for 1:1
    const normalized = amount * 10n ** 12n;
    if (normalized > 0n) {
      const diff = normalized > ghoAmount ? normalized - ghoAmount : ghoAmount - normalized;
      priceImpactBps = Number((diff * 10000n) / normalized);
    }
  }

  const isLoading = gsmPreview.isLoading || sharesPreview.isLoading;
  const isError = gsmPreview.isError || sharesPreview.isError;

  const preview: DepositPreview | undefined =
    ghoAmount !== undefined && estimatedShares !== undefined
      ? { ghoAmount, estimatedShares, fee, priceImpactBps }
      : undefined;

  return { preview, isLoading, isError };
}

"use client";

import { formatTokenAmount, formatFee, formatBps } from "@/lib/formatting";
import type { DepositPreview, RedeemPreview, SupportedToken } from "@/types";

interface DepositPreviewProps {
  type: "deposit";
  preview: DepositPreview | undefined;
}

interface RedeemPreviewProps {
  type: "redeem";
  preview: RedeemPreview | undefined;
  outputToken: SupportedToken;
}

type TransactionPreviewProps = DepositPreviewProps | RedeemPreviewProps;

/**
 * Aave-style transaction details section.
 */
export function TransactionPreview(props: TransactionPreviewProps) {
  if (props.type === "deposit") return <DepositRows {...props} />;
  return <RedeemRows {...props} />;
}

function DepositRows({ preview }: DepositPreviewProps) {
  if (!preview) return null;
  const showImpact = preview.priceImpactBps > 100;

  return (
    <div className="space-y-2.5 border-t border-[var(--border-secondary)] pt-4">
      <DetailRow label="GHO deposited" value={`${formatTokenAmount(preview.ghoAmount, 18)} GHO`} />
      <DetailRow
        label="You receive"
        value={`${formatTokenAmount(preview.estimatedShares, 18)} sGHO`}
        highlight
      />
      {preview.fee > 0n && (
        <DetailRow label="GSM fee" value={formatFee(preview.fee, 18, "GHO")} />
      )}
      <DetailRow label="Quote slippage" value={formatBps(preview.priceImpactBps)} />
      {showImpact && <PriceImpactWarning bps={preview.priceImpactBps} />}
    </div>
  );
}

function RedeemRows({ preview, outputToken }: RedeemPreviewProps) {
  if (!preview) return null;
  const outDec = outputToken === "GHO" ? 18 : 6;
  const showImpact = preview.priceImpactBps > 100;

  return (
    <div className="space-y-2.5 border-t border-[var(--border-secondary)] pt-4">
      <DetailRow label="GHO redeemed" value={`${formatTokenAmount(preview.ghoAmount, 18)} GHO`} />
      <DetailRow
        label="You receive"
        value={`${formatTokenAmount(preview.estimatedOutput, outDec)} ${outputToken}`}
        highlight
      />
      {preview.fee > 0n && (
        <DetailRow label="GSM fee" value={formatFee(preview.fee, 18, "GHO")} />
      )}
      <DetailRow label="Quote slippage" value={formatBps(preview.priceImpactBps)} />
      {showImpact && <PriceImpactWarning bps={preview.priceImpactBps} />}
    </div>
  );
}

function DetailRow({ label, value, highlight = false }: { label: string; value: string; highlight?: boolean }) {
  return (
    <div className="flex items-center justify-between text-sm">
      <span className="text-[var(--text-muted)]">{label}</span>
      <span className={highlight ? "font-semibold text-[var(--text-primary)]" : "text-[var(--text-secondary)]"}>
        {value}
      </span>
    </div>
  );
}

function PriceImpactWarning({ bps }: { bps: number }) {
  return (
    <div className="flex items-center gap-2 rounded-md bg-[var(--warning)]/10 px-3 py-2 text-xs text-[var(--warning)]">
      <svg className="h-3.5 w-3.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      <span>Price impact: {formatBps(bps)}</span>
    </div>
  );
}

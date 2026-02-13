import { formatUnits } from "viem";

/**
 * Format a bigint token amount for display.
 * @param amount Raw token amount in smallest unit.
 * @param decimals Token decimals.
 * @param displayDecimals Number of decimal places to display (default 4).
 */
export function formatTokenAmount(
  amount: bigint,
  decimals: number,
  displayDecimals = 4
): string {
  const formatted = formatUnits(amount, decimals);
  const num = parseFloat(formatted);

  if (num === 0) return "0";
  if (num < 10 ** -displayDecimals) return `<${(10 ** -displayDecimals).toFixed(displayDecimals)}`;

  return num.toLocaleString("en-US", {
    minimumFractionDigits: 0,
    maximumFractionDigits: displayDecimals,
  });
}

/**
 * Format an address for display (0x1234...abcd).
 */
export function formatAddress(address: string): string {
  if (!address || address.length < 10) return address;
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

/**
 * Format basis points as a percentage string.
 */
export function formatBps(bps: number): string {
  return `${(bps / 100).toFixed(2)}%`;
}

/**
 * Format a fee amount with token symbol.
 */
export function formatFee(fee: bigint, decimals: number, symbol: string): string {
  if (fee === 0n) return `0 ${symbol}`;
  return `${formatTokenAmount(fee, decimals, 6)} ${symbol}`;
}

/**
 * Build an Etherscan transaction URL.
 */
export function getTxUrl(txHash: string, chainId: number = 1): string {
  if (chainId === 1) {
    return `https://etherscan.io/tx/${txHash}`;
  }
  return `#tx-${txHash}`;
}

/**
 * Build an Etherscan address URL.
 */
export function getAddressUrl(address: string, chainId: number = 1): string {
  if (chainId === 1) {
    return `https://etherscan.io/address/${address}`;
  }
  return `#address-${address}`;
}

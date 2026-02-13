import {
  createTestClient,
  createWalletClient,
  createPublicClient,
  http,
  encodeFunctionData,
  type Address,
} from "viem";
import { hardhat } from "viem/chains";
import { erc20Abi } from "@/abi/erc20";
import { erc4626Abi } from "@/abi/erc4626";
import { addresses } from "@/config/addresses";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const FORK_SETUP_HINT =
  "Start Anvil in mainnet-fork mode (anvil --fork-url <MAINNET_RPC_URL> --chain-id 31337 --port 8545) and ensure NEXT_PUBLIC_ANVIL_RPC_URL points to it.";

// --------------- Whale addresses (mainnet holders) ---------------
const WHALES = {
  // Binance 14
  BINANCE: "0x28C6c06298d514Db089934071355E5743bf21d60" as Address,
  // Binance hot wallet
  BINANCE_8: "0xF977814e90dA44bFA03b6295A0616a897441aceC" as Address,
  // Binance hot wallet
  BINANCE_7: "0x21a31Ee1afC51d94C2eFcCAa2092aD1028285549" as Address,
  // Curve 3pool (deep USDC/USDT liquidity)
  CURVE_3POOL: "0xbebc44782c7dB0a1A60Cb6Fe97d0b483032FF1C7" as Address,
  // Aave V3 pool (large stablecoin reserves)
  AAVE_V3_POOL: "0x87870Bca3F3fD6335C3f4ce8392D69350B4fa4E2" as Address,
  // Tether Treasury
  TETHER_TREASURY: "0x5754284f345afc66a98fbb0a0afe71e0f007b949" as Address,
  // Aave Collector / Treasury - holds GHO
  AAVE_COLLECTOR: "0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c" as Address,
  // Fallback GHO whale
  GHO_WHALE_2: "0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016" as Address,
};

const USDC_WHALES: Address[] = [
  WHALES.BINANCE,
  WHALES.BINANCE_8,
  WHALES.BINANCE_7,
  WHALES.CURVE_3POOL,
  WHALES.AAVE_V3_POOL,
];

const USDT_WHALES: Address[] = [
  WHALES.BINANCE,
  WHALES.BINANCE_8,
  WHALES.BINANCE_7,
  WHALES.CURVE_3POOL,
  WHALES.TETHER_TREASURY,
  WHALES.AAVE_V3_POOL,
];

// --------------- Drip amounts ---------------
export const DRIP_AMOUNTS = {
  ETH: 100n * 10n ** 18n, // 100 ETH
  USDC: 100_000n * 10n ** 6n, // 100,000 USDC
  USDT: 100_000n * 10n ** 6n, // 100,000 USDT
  GHO: 100_000n * 10n ** 18n, // 100,000 GHO
  SGHO_DEPOSIT: 50_000n * 10n ** 18n, // 50,000 GHO -> sGHO
};

export type FaucetToken = "ETH" | "USDC" | "USDT" | "GHO" | "sGHO";

export interface FaucetResult {
  token: FaucetToken;
  success: boolean;
  error?: string;
}

type FaucetClients = ReturnType<typeof getClients>;

class FaucetConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "FaucetConfigError";
  }
}

function getRpcUrl(): string {
  return process.env.NEXT_PUBLIC_ANVIL_RPC_URL || "http://127.0.0.1:8545";
}

function getClients() {
  const transport = http(getRpcUrl());
  const chain = hardhat;

  const testClient = createTestClient({
    mode: "anvil",
    chain,
    transport,
  });

  const publicClient = createPublicClient({
    chain,
    transport,
  });

  return { testClient, publicClient, transport, chain };
}

function faucetConfigError(message: string): FaucetConfigError {
  return new FaucetConfigError(`${message} ${FORK_SETUP_HINT}`);
}

function formatFaucetError(error: unknown): string {
  if (error instanceof FaucetConfigError) return error.message;

  const message = error instanceof Error ? error.message : String(error);

  if (
    message.includes("ECONNREFUSED") ||
    message.includes("fetch failed") ||
    message.includes("Failed to fetch")
  ) {
    return faucetConfigError(`Cannot reach RPC at ${getRpcUrl()}.`).message;
  }

  if (message.includes("Method not found")) {
    return faucetConfigError(`RPC at ${getRpcUrl()} does not support Anvil methods.`).message;
  }

  if (message.includes("returned no data")) {
    return faucetConfigError("Mainnet token contracts are missing on the configured RPC.").message;
  }

  return message;
}

async function assertForkReady(clients: FaucetClients, token: Address): Promise<void> {
  const { publicClient, testClient } = clients;

  let chainId: number;
  try {
    chainId = await publicClient.getChainId();
  } catch {
    throw faucetConfigError(`Cannot read chain ID from RPC at ${getRpcUrl()}.`);
  }

  if (chainId !== 31337) {
    throw faucetConfigError(`Configured RPC returned chain ID ${chainId}, expected 31337.`);
  }

  try {
    await testClient.impersonateAccount({ address: WHALES.BINANCE });
    await testClient.stopImpersonatingAccount({ address: WHALES.BINANCE });
  } catch {
    throw faucetConfigError(`RPC at ${getRpcUrl()} does not support impersonation.`);
  }

  const code = await publicClient.getBytecode({ address: token });
  if (!code || code === "0x") {
    throw faucetConfigError(`No token contract is deployed at ${token}.`);
  }
}

async function impersonateAndTransfer(
  token: Address,
  whale: Address,
  recipient: Address,
  amount: bigint
): Promise<void> {
  const clients = getClients();
  const { testClient, publicClient, transport, chain } = clients;
  await assertForkReady(clients, token);

  // Fund whale with ETH for gas
  await testClient.setBalance({
    address: whale,
    value: 10n * 10n ** 18n,
  });

  // Impersonate
  await testClient.impersonateAccount({ address: whale });

  try {
    // Check whale balance first
    const balance = await publicClient.readContract({
      address: token,
      abi: erc20Abi,
      functionName: "balanceOf",
      args: [whale],
    }) as bigint;

    if (balance < amount) {
      throw new Error(`Whale ${whale.slice(0, 10)}... has insufficient balance`);
    }

    // Build transfer calldata
    const data = encodeFunctionData({
      abi: erc20Abi,
      functionName: "transfer",
      args: [recipient, amount],
    });

    // Send from impersonated account
    const walletClient = createWalletClient({
      account: whale,
      chain,
      transport,
    });

    const hash = await walletClient.sendTransaction({
      to: token,
      data,
    });

    await publicClient.waitForTransactionReceipt({ hash });
  } finally {
    await testClient.stopImpersonatingAccount({ address: whale });
  }
}

function isInsufficientBalanceError(error: unknown): boolean {
  const message = formatFaucetError(error).toLowerCase();
  return message.includes("insufficient balance");
}

async function impersonateAndTransferWithFallbackWhales(
  token: Address,
  whales: Address[],
  recipient: Address,
  amount: bigint
): Promise<void> {
  const uniqueWhales = [...new Set(whales)];
  const attempted: string[] = [];

  for (const whale of uniqueWhales) {
    try {
      await impersonateAndTransfer(token, whale, recipient, amount);
      return;
    } catch (error) {
      if (isInsufficientBalanceError(error)) {
        attempted.push(whale);
        continue;
      }
      throw error;
    }
  }

  throw new Error(
    `No whale with sufficient balance found for token ${token}. Attempted: ${attempted.join(", ")}`
  );
}

/**
 * Drip ETH to recipient using anvil_setBalance.
 */
export async function dripETH(recipient: Address): Promise<FaucetResult> {
  try {
    const { testClient } = getClients();
    await testClient.setBalance({
      address: recipient,
      value: DRIP_AMOUNTS.ETH,
    });
    return { token: "ETH", success: true };
  } catch (e) {
    return { token: "ETH", success: false, error: formatFaucetError(e) };
  }
}

/**
 * Drip USDC by impersonating fallback whales.
 */
export async function dripUSDC(recipient: Address): Promise<FaucetResult> {
  try {
    await impersonateAndTransferWithFallbackWhales(
      addresses.USDC,
      USDC_WHALES,
      recipient,
      DRIP_AMOUNTS.USDC
    );
    return { token: "USDC", success: true };
  } catch (e) {
    return { token: "USDC", success: false, error: formatFaucetError(e) };
  }
}

/**
 * Drip USDT by impersonating fallback whales.
 */
export async function dripUSDT(recipient: Address): Promise<FaucetResult> {
  try {
    await impersonateAndTransferWithFallbackWhales(
      addresses.USDT,
      USDT_WHALES,
      recipient,
      DRIP_AMOUNTS.USDT
    );
    return { token: "USDT", success: true };
  } catch (e) {
    return { token: "USDT", success: false, error: formatFaucetError(e) };
  }
}

/**
 * Drip GHO by impersonating Aave Treasury (with fallback whale).
 */
export async function dripGHO(recipient: Address): Promise<FaucetResult> {
  const whales = [WHALES.AAVE_COLLECTOR, WHALES.GHO_WHALE_2];

  for (const whale of whales) {
    try {
      await impersonateAndTransfer(
        addresses.GHO,
        whale,
        recipient,
        DRIP_AMOUNTS.GHO
      );
      return { token: "GHO", success: true };
    } catch (e) {
      const error = formatFaucetError(e);
      if (error.toLowerCase().includes("insufficient balance")) {
        continue;
      }
      return { token: "GHO", success: false, error };
    }
  }

  return {
    token: "GHO",
    success: false,
    error: "No whale with sufficient GHO balance found",
  };
}

/**
 * Mint sGHO by impersonating the recipient and depositing GHO into the vault.
 * Requires that the recipient already has enough GHO.
 */
export async function dripSGHO(recipient: Address): Promise<FaucetResult> {
  const sgho = addresses.sGHO;
  if (!sgho || sgho === ZERO_ADDRESS) {
    return {
      token: "sGHO",
      success: false,
      error: "NEXT_PUBLIC_SGHO_ADDRESS not configured",
    };
  }

  try {
    const { testClient, publicClient, transport, chain } = getClients();

    // Impersonate the recipient so they can approve + deposit
    await testClient.impersonateAccount({ address: recipient });

    const walletClient = createWalletClient({
      account: recipient,
      chain,
      transport,
    });

    // Approve sGHO vault to spend GHO
    const approveData = encodeFunctionData({
      abi: erc20Abi,
      functionName: "approve",
      args: [sgho, DRIP_AMOUNTS.SGHO_DEPOSIT],
    });

    const approveTx = await walletClient.sendTransaction({
      to: addresses.GHO,
      data: approveData,
    });
    await publicClient.waitForTransactionReceipt({ hash: approveTx });

    // Deposit GHO into sGHO (ERC4626)
    const depositData = encodeFunctionData({
      abi: erc4626Abi,
      functionName: "deposit",
      args: [DRIP_AMOUNTS.SGHO_DEPOSIT, recipient],
    });

    // Check the sGHO contract has a deposit function first
    const depositTx = await walletClient.sendTransaction({
      to: sgho,
      data: depositData,
    });
    await publicClient.waitForTransactionReceipt({ hash: depositTx });

    await testClient.stopImpersonatingAccount({ address: recipient });

    return { token: "sGHO", success: true };
  } catch (e) {
    // Best-effort stop impersonation
    try {
      const { testClient } = getClients();
      await testClient.stopImpersonatingAccount({ address: recipient });
    } catch {}
    return { token: "sGHO", success: false, error: formatFaucetError(e) };
  }
}

/**
 * Drip all tokens to the recipient.
 */
export async function dripAll(recipient: Address): Promise<FaucetResult[]> {
  const results: FaucetResult[] = [];

  results.push(await dripETH(recipient));
  results.push(await dripUSDC(recipient));
  results.push(await dripUSDT(recipient));
  results.push(await dripGHO(recipient));

  return results;
}

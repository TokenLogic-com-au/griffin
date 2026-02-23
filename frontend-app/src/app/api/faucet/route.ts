import { NextResponse } from "next/server";
import { isAddress, type Address } from "viem";
import {
  dripAll,
  dripETH,
  dripUSDC,
  dripUSDT,
  dripGHO,
  isFaucetEnabled,
  type FaucetResult,
  type FaucetToken,
} from "@/lib/faucet";

export const runtime = "nodejs";

type FaucetUiToken = Exclude<FaucetToken, "sGHO">;

type FaucetRequest = {
  token: FaucetUiToken | "all";
  recipient: string;
};

const TOKEN_DRIPPERS: Record<FaucetUiToken, (recipient: Address) => Promise<FaucetResult>> = {
  ETH: dripETH,
  USDC: dripUSDC,
  USDT: dripUSDT,
  GHO: dripGHO,
};

function badRequest(error: string, status = 400) {
  return NextResponse.json({ error }, { status });
}

function isValidToken(token: unknown): token is FaucetUiToken | "all" {
  return token === "all" || token === "ETH" || token === "USDC" || token === "USDT" || token === "GHO";
}

export async function POST(request: Request) {
  let body: Partial<FaucetRequest>;
  try {
    body = (await request.json()) as Partial<FaucetRequest>;
  } catch {
    return badRequest("Invalid JSON body.");
  }

  const { token, recipient } = body;

  if (!isValidToken(token)) {
    return badRequest("Invalid faucet token.");
  }

  if (!recipient || !isAddress(recipient)) {
    return badRequest("Invalid recipient address.");
  }

  if (!isFaucetEnabled()) {
    return badRequest("Faucet is only available on configured fork networks.", 403);
  }

  try {
    let results: FaucetResult[];

    if (token === "all") {
      results = await dripAll(recipient as Address);
    } else {
      const result = await TOKEN_DRIPPERS[token](recipient as Address);
      results = [result];
    }

    return NextResponse.json({ results });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}

import { createConfig } from "wagmi";
import { getDefaultConfig } from "connectkit";
import { targetChain, getTransport } from "./chains";

const rawWalletConnectProjectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID?.trim();

// Treat missing or placeholder IDs as "WalletConnect not configured".
// ConnectKit omits the WalletConnect connector when this is an empty string.
const walletConnectProjectId =
  rawWalletConnectProjectId && rawWalletConnectProjectId !== "placeholder_replace_me"
    ? rawWalletConnectProjectId
    : "";

export const wagmiConfig = createConfig(
  getDefaultConfig({
    chains: [targetChain],
    transports: {
      [targetChain.id]: getTransport(),
    },
    walletConnectProjectId,
    appName: "sGHO Router",
    appDescription: "Deposit and redeem sGHO using GHO, USDC, or USDT",
  })
);

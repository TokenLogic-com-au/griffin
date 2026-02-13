"use client";

import { ConnectKitButton } from "connectkit";
import { useMounted } from "@/hooks/useMounted";

export function ConnectWallet() {
  const mounted = useMounted();

  if (!mounted) {
    return (
      <button className="btn-primary text-sm">
        Connect wallet
      </button>
    );
  }

  return (
    <ConnectKitButton.Custom>
      {({ isConnected, show, truncatedAddress, ensName }) => (
        <button
          onClick={show}
          className={isConnected
            ? "btn-ghost"
            : "btn-primary text-sm"
          }
        >
          {isConnected ? ensName ?? truncatedAddress : "Connect wallet"}
        </button>
      )}
    </ConnectKitButton.Custom>
  );
}

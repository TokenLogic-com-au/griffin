"use client";

import { useSyncExternalStore } from "react";

/**
 * Returns true only after the component has mounted on the client.
 * Use this to guard any rendering that depends on client-only state
 * (wallet connection, window, etc.) to avoid SSR hydration mismatches.
 */
export function useMounted(): boolean {
  return useSyncExternalStore(
    () => () => {},
    () => true,
    () => false
  );
}

import type { AnalyticsEvent } from "@/types";

/**
 * Analytics tracking stub.
 * Replace the implementation body with your analytics provider
 * (e.g. Mixpanel, Amplitude, PostHog, or a custom backend).
 */
export function trackEvent(event: AnalyticsEvent): void {
  if (process.env.NODE_ENV === "development") {
    console.log("[analytics]", event.type, event);
  }
  // TODO: integrate analytics provider
  // Example:
  // posthog.capture(event.type, event);
}

/**
 * Track a deposit flow drop-off at a specific step.
 */
export function trackDepositDropOff(
  step: "token_select" | "amount_input" | "approval" | "confirm" | "submit",
  reason?: string
): void {
  trackEvent({
    type: "deposit_failed",
    token: "GHO",
    reason: `drop_off_${step}${reason ? `: ${reason}` : ""}`,
  });
}

/**
 * Track a redeem flow drop-off at a specific step.
 */
export function trackRedeemDropOff(
  step: "shares_input" | "token_select" | "approval" | "confirm" | "submit",
  reason?: string
): void {
  trackEvent({
    type: "redeem_failed",
    token: "GHO",
    reason: `drop_off_${step}${reason ? `: ${reason}` : ""}`,
  });
}

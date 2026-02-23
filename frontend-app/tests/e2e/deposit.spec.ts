import { test, expect } from "@playwright/test";

/**
 * E2E tests for the deposit flow.
 * These tests verify UI behavior without a connected wallet (wallet interaction
 * requires a browser extension or Anvil fork with impersonation, which is
 * covered by integration test infrastructure).
 */

test.describe("Deposit Flow - UI", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/");
    await page.locator(".hero-card").getByRole("button", { name: "Deposit", exact: true }).click();
    await expect(page.getByTestId("tab-deposit")).toBeVisible();
  });

  test("renders deposit tab by default", async ({ page }) => {
    const depositTab = page.getByTestId("tab-deposit");
    await expect(depositTab).toBeVisible();
    // Deposit tab should be active
    await expect(depositTab).toHaveClass(/tab-active/);
  });

  test("shows connect wallet prompt when not connected", async ({ page }) => {
    await expect(page.getByText("Connect a wallet to get started")).toBeVisible();
  });

  test("can switch between deposit and redeem tabs", async ({ page }) => {
    const redeemTab = page.getByTestId("tab-redeem");
    await redeemTab.click();
    await expect(redeemTab).toHaveClass(/tab-active/);

    const depositTab = page.getByTestId("tab-deposit");
    await expect(depositTab).toHaveClass(/tab-inactive/);
  });

  test("shows disconnected state content for deposit", async ({ page }) => {
    await expect(page.getByText("Connect a wallet to get started")).toBeVisible();
  });

  test("shows disconnected state content for redeem", async ({ page }) => {
    await page.getByTestId("tab-redeem").click();
    await expect(page.getByText("Connect a wallet to get started")).toBeVisible();
  });

  test("page has correct title", async ({ page }) => {
    await expect(page).toHaveTitle(/sGHO Router/);
  });

  test("header displays app name", async ({ page }) => {
    await expect(page.getByRole("heading", { name: "sGHO Router" })).toBeVisible();
  });
});

test.describe("Deposit Flow - Validation (requires wallet)", () => {
  // These tests would run against an Anvil fork with a funded wallet.
  // Skipped in CI without proper setup.

  test.skip("blocks zero amount submission", async ({ page }) => {
    // This test requires wallet connection via a test helper
    // Implementation: connect wallet -> enter "0" -> verify button is disabled
  });

  test.skip("blocks amount exceeding balance", async ({ page }) => {
    // Connect wallet -> enter amount > balance -> verify error message
  });

  test.skip("shows preview for valid GHO amount", async ({ page }) => {
    // Connect wallet -> enter valid GHO amount -> verify preview section
  });

  test.skip("shows approval step for USDC deposit", async ({ page }) => {
    // Connect wallet -> select USDC -> enter amount -> verify approval step shown
  });

  test.skip("handles user rejection gracefully", async ({ page }) => {
    // Connect wallet -> initiate tx -> reject in wallet -> verify error display
  });
});

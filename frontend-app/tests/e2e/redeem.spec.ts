import { test, expect } from "@playwright/test";

/**
 * E2E tests for the redeem flow.
 * UI-only tests run without wallet; integration tests require Anvil fork.
 */

test.describe("Redeem Flow - UI", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/");
    await page.getByTestId("tab-redeem").click();
  });

  test("redeem tab is active after click", async ({ page }) => {
    const redeemTab = page.getByTestId("tab-redeem");
    await expect(redeemTab).toHaveClass(/tab-active/);
  });

  test("shows connect wallet prompt", async ({ page }) => {
    await expect(page.getByText("Connect your wallet to get started")).toBeVisible();
  });

  test("how it works shows redeem steps", async ({ page }) => {
    await expect(page.getByText("Enter the amount of sGHO shares")).toBeVisible();
    await expect(page.getByText("Choose your desired output token")).toBeVisible();
  });
});

test.describe("Redeem Flow - Network", () => {
  test.skip("shows wrong network overlay on unsupported chain", async ({ page }) => {
    // Requires wallet connected to wrong chain
    // Verify: NetworkGuard overlay is visible with switch button
  });

  test.skip("switches network when prompted", async ({ page }) => {
    // Requires wallet automation
    // Verify: overlay disappears after chain switch
  });
});

test.describe("Redeem Flow - Contract Revert", () => {
  test.skip("displays InvalidAmount revert message", async ({ page }) => {
    // Against Anvil fork: try to redeem 0 shares
    // Verify: ErrorDisplay shows "Amount must be greater than zero"
  });

  test.skip("displays SlippageExceeded revert message", async ({ page }) => {
    // Against Anvil fork: set minOutputAmount very high
    // Verify: ErrorDisplay shows slippage-related message
  });
});

# sGHO Router Frontend

A Next.js frontend for depositing and redeeming sGHO shares using GHO, USDC, or USDT through the sGHORouter smart contract.

## Supported Assets

| Token | Decimals | Role |
|-------|----------|------|
| GHO   | 18       | Deposit input / Redeem output |
| USDC  | 6        | Deposit input / Redeem output (routed via GSM) |
| USDT  | 6        | Deposit input / Redeem output (routed via GSM) |
| sGHO  | 18       | ERC4626 vault shares |

## Architecture

```
src/
  app/           Layout, page, providers (Next.js App Router)
  abi/           Typed ABIs for sGHORouter, GSMRouter, ERC20, ERC4626
  config/        Contract addresses (env-driven), chain config, token metadata, wagmi config
  hooks/         React hooks for balances, allowances, previews, deposits, redeems, network guard
  components/    UI components: forms, token selector, previews, transaction status, error display
  lib/           Error parsing/mapping, input validation, number formatting, analytics stubs
  types/         Shared TypeScript types
tests/
  unit/          Vitest: error decoder, validation, formatting
  e2e/           Playwright: deposit/redeem UI flows
```

### Data Flow

**Deposit:** User selects token + amount -> preview via GSMRouter.previewSwapToGHO + sGHO.previewDeposit -> approve token (if needed) -> sGHORouter.deposit() -> watch Deposited event -> refresh balances.

**Redeem:** User enters sGHO shares + output token -> preview via sGHO.previewRedeem + GSMRouter.previewSwapFromGHO -> approve sGHO (if needed) -> sGHORouter.redeem() -> watch Redeemed event -> refresh balances.

## Setup

### Prerequisites

- Node.js >= 18
- npm
- [Foundry](https://book.getfoundry.sh/) (for Anvil local fork)

### Install

```bash
cd frontend-app
npm install
```

### Environment Variables

Copy `.env.example` to `.env.local` and fill in values:

```bash
cp .env.example .env.local
```

| Variable | Description | Required |
|----------|-------------|----------|
| `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` | WalletConnect Cloud project ID | Yes |
| `NEXT_PUBLIC_SGHO_ROUTER_ADDRESS` | Deployed sGHORouter address | Yes |
| `NEXT_PUBLIC_GSM_ROUTER_ADDRESS` | Deployed GSMRouter address | Yes |
| `NEXT_PUBLIC_SGHO_ADDRESS` | sGHO vault address | Yes |
| `NEXT_PUBLIC_GHO_ADDRESS` | GHO token address | Has mainnet default |
| `NEXT_PUBLIC_USDC_ADDRESS` | USDC token address | Has mainnet default |
| `NEXT_PUBLIC_USDT_ADDRESS` | USDT token address | Has mainnet default |
| `NEXT_PUBLIC_GSM_USDC_ADDRESS` | GSM USDC address | Has mainnet default |
| `NEXT_PUBLIC_GSM_USDT_ADDRESS` | GSM USDT address | Has mainnet default |
| `NEXT_PUBLIC_CHAIN_ID` | Target chain ID (1 = mainnet, 31337 = Anvil) | Default: 1 |
| `NEXT_PUBLIC_ANVIL_RPC_URL` | Anvil fork RPC URL | For local dev |

### Local Development with Anvil Fork

1. Start an Anvil fork of Ethereum mainnet:

```bash
anvil --fork-url https://eth.llamarpc.com --chain-id 31337
```

2. Deploy contracts to the fork (from the `contracts/` directory):

```bash
cd ../contracts
forge script script/DeploySGHORouter.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

3. Update `.env.local` with the deployed addresses and set `NEXT_PUBLIC_CHAIN_ID=31337`.

4. Start the dev server:

```bash
npm run dev
```

5. Open http://localhost:3000 and connect MetaMask to `localhost:8545`.

### Production

Set all `NEXT_PUBLIC_*` env vars to mainnet contract addresses and `NEXT_PUBLIC_CHAIN_ID=1`.

```bash
npm run build
npm start
```

## Testing

### Unit Tests

```bash
npm test
```

Covers: error parsing/mapping, input validation, number formatting, slippage calculation.

### E2E Tests

```bash
npx playwright install  # first time only
npm run test:e2e
```

UI-level tests run against the dev server. Integration tests requiring wallet interaction are scaffolded but need Anvil fork + funded accounts.

## User Flows

### Deposit

1. Connect wallet (Ethereum mainnet or Anvil fork).
2. Select input token: GHO, USDC, or USDT.
3. Enter amount. Preview shows estimated sGHO shares, fees, and price impact.
4. Adjust slippage tolerance if needed (default 0.5%).
5. Click Deposit. If approval is needed, the UI shows a two-step flow:
   - Step 1: Approve token spending (exact amount, not unlimited).
   - Step 2: Execute deposit via sGHORouter.
6. Transaction status updates in real-time (pending, confirming, success/error).
7. On success: Deposited event details shown, balances refresh.

### Redeem

1. Enter sGHO shares to redeem. MAX button fills full balance.
2. Select output token: GHO, USDC, or USDT.
3. Preview shows estimated output amount, fees, and price impact.
4. Click Redeem. Approval step shown if sGHO allowance is insufficient.
5. Transaction lifecycle tracked with step-by-step status.
6. On success: Redeemed event details shown, balances refresh.

## Error Handling

Contract revert reasons are decoded from the ABI and mapped to user-friendly messages:

| Error | Message |
|-------|---------|
| `InvalidToken` | The selected token is not supported by the router. |
| `InvalidAmount` | The amount must be greater than zero. |
| `SlippageExceeded` | Output was less than minimum. Try increasing slippage. |
| `InvalidConfiguration` | The router contract is misconfigured. |
| `InvalidGsm` | The GHO Stability Module is not available for this token. |

User wallet rejections are detected and shown as dismissible warnings.

## Caveats

- USDC/USDT deposits route through GSM, which charges a fee. The preview accounts for this.
- stataToken interest accrual between preview and execution can cause minor output drift -- slippage tolerance protects against this.
- sGHORouter and GSMRouter addresses must be set before the app is functional. Zero-address defaults will cause transactions to fail.
- The router uses exact approvals (not unlimited) for security. Each new deposit amount may require a fresh approval if the previous one was consumed.

## License

MIT

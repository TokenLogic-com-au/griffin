# CLAUDE.md

Agent instructions for working with the Griffin (sGHO Router) monorepo.

## Repository Structure

```
griffin/
  contracts/          Foundry-based Solidity smart contracts
  frontend-app/       Next.js 16 frontend for sGHO deposit/redeem
```

## Contracts (`contracts/`)

### Tech Stack
- Solidity 0.8.30, Foundry, Solc with Cancun EVM target
- OpenZeppelin via `@openzeppelin/=lib/openzeppelin-contracts/`

### Key Contracts
- `src/contracts/onboarding/sGHORouter.sol` — Main router: deposits USDC/USDT/GHO into sGHO, redeems sGHO to USDC/USDT/GHO
- `src/contracts/onboarding/GSMRouter.sol` — Lower-level: swaps USDC/USDT to GHO via GSM (stataToken wrapping)
- `src/interfaces/onboarding/ISGHORouter.sol` — sGHORouter interface with events and errors
- `src/interfaces/onboarding/IGSMRouter.sol` — GSMRouter interface with preview functions

### Contract Functions (sGHORouter)
- `deposit(token, amount, minOutputAmount) → shares` — Deposit GHO/USDC/USDT, receive sGHO shares
- `redeem(shares, token, minOutputAmount) → amountOut` — Redeem sGHO shares for GHO/USDC/USDT
- Events: `Deposited`, `Redeemed`, `DustReturned`
- Custom errors: `ZeroAddress`, `InvalidToken`, `InvalidAmount`, `SlippageExceeded`, `InvalidConfiguration`

### Contract Functions (GSMRouter)
- `swapToGHO(gsm, amount, minGHOAmount)` — Swap underlying to GHO
- `swapFromGHO(gsm, ghoAmount, minOutputAmount)` — Swap GHO to underlying
- `previewSwapToGHO(gsm, amount)` — Preview swap (view)
- `previewSwapFromGHO(gsm, ghoAmount)` — Preview reverse swap (view)

### Token Addresses (Ethereum Mainnet)
- GHO: `0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f` (18 decimals)
- USDC: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` (6 decimals)
- USDT: `0xdAC17F958D2ee523a2206206994597C13D831ec7` (6 decimals)
- GSM USDC: `0xFeeb6FE430B7523fEF2a38327241eE7153779535`
- GSM USDT: `0x535b2f7C20B9C83d70e519cf9991578eF9816B7B`

### Build & Test
```bash
cd contracts
forge build
forge test --fork-url https://eth.llamarpc.com -vvv
```

## Frontend (`frontend-app/`)

### Tech Stack
- Next.js 16 (App Router, Turbopack), React 18, TypeScript
- wagmi 2.19 + viem 2.45 + ConnectKit 1.9 for wallet/contract interaction
- Tailwind CSS 3 for styling
- ESLint 9 (flat config), Vitest for unit tests, Playwright for E2E
- Anvil (Foundry) for local fork development

### Project Layout
```
src/
  app/            Next.js App Router (layout, page, providers, globals.css)
  abi/            Typed ABIs: sGHORouter, GSMRouter, ERC20, ERC4626
  config/         addresses.ts, chains.ts, tokens.ts, wagmi.ts
  hooks/          useTokenBalances, useAllowance, useApprove, useDeposit, useRedeem,
                  usePreviewDeposit, usePreviewRedeem, useNetworkGuard, useFaucet, useMounted
  components/     ConnectWallet, NetworkGuard, TokenSelector, AmountInput, DepositForm,
                  RedeemForm, TransactionPreview, TransactionStatus, ErrorDisplay,
                  BalanceDisplay, FaucetPanel
  lib/            errors.ts, validation.ts, formatting.ts, analytics.ts, faucet.ts
  types/          Shared TypeScript types
scripts/
  faucet.sh       Drip test tokens on Anvil fork via cast impersonation
  deploy-local.sh Deploy GSMRouter + sGHORouter to Anvil fork, writes .env.local
tests/
  unit/           Vitest: error parsing, validation, formatting
  e2e/            Playwright: deposit/redeem UI flows
```

### Key Configuration
- All contract addresses are driven by `NEXT_PUBLIC_*` env vars in `.env.local`
- Chain ID: `NEXT_PUBLIC_CHAIN_ID` (1 = mainnet, 31337 = Anvil fork)
- `next.config.mjs` has both `turbopack: {}` and `webpack` fallback configs
- ESLint uses flat config (`eslint.config.mjs`) with `@eslint/eslintrc` FlatCompat shim
- Vitest excludes `tests/e2e/**`, `node_modules/**`, and `.next/**`

### Build & Test
```bash
cd frontend-app
npm install
npm run build          # Production build (Turbopack)
npm test               # Unit tests (Vitest)
npm run lint           # ESLint
npm run test:e2e       # E2E tests (Playwright)
```

### Local Development Workflow
```bash
# Terminal 1: Start Anvil fork
anvil --fork-url https://eth.llamarpc.com --chain-id 31337

# Terminal 2: Deploy contracts + configure env
cd frontend-app
npm run deploy:local

# Terminal 2: Drip test tokens to your wallet
npm run faucet -- 0xYourAddress

# Terminal 2: Start dev server
npm run dev
```

### Important Architecture Notes
- `useMounted()` hook gates all wallet-dependent rendering to prevent SSR hydration mismatches. Always use `const connected = mounted && isConnected` instead of raw `isConnected` in page-level components.
- ConnectKit 1.9 peers on wagmi 2.x — do not upgrade wagmi to 3.x until ConnectKit supports it.
- The faucet (both `scripts/faucet.sh` and `src/lib/faucet.ts`) uses Anvil's `anvil_impersonateAccount` to transfer tokens from mainnet whales (Binance for USDC/USDT, Aave Treasury for GHO). The UI faucet panel only renders when `targetChain.id === 31337`.
- sGHORouter uses exact approvals, not unlimited. Each new deposit amount may require a fresh ERC20 approval.
- USDC/USDT deposits route through GSMRouter (which wraps into stataTokens then sells via GSM). GHO deposits go directly into the sGHO ERC4626 vault.
- The `deploy-local.sh` script uses Anvil default private key #0 (`0xac0974...`) and writes deployed addresses into `.env.local`.

### Branding
- Dark navy Aave V3 palette: #0d0f1a (bg), #15172b (cards), #1c1f36 (surfaces)
- Aave gradient: #B6509E (purple) to #2EBAC6 (teal) on CTA buttons, tab indicators, logo
- Aave ghost SVG mark in navbar, "Built by TokenLogic" in footer
- CSS variables use `--aave-teal` and `--aave-purple` naming

### Error Handling
Contract revert reasons are decoded in `lib/errors.ts` and mapped to user-facing messages:
- `InvalidToken` → "The selected token is not supported"
- `InvalidAmount` → "The amount must be greater than zero"
- `SlippageExceeded` → "Output was less than minimum, try increasing slippage"
- `InvalidConfiguration` → "The router contract is misconfigured"
- User wallet rejections are detected via string pattern matching and shown as dismissible warnings

### Conventions
- Do not commit `.env.local` (contains local contract addresses)
- ABI files in `src/abi/` are hand-written `as const` arrays matching the Solidity interfaces
- Token decimals: GHO = 18, USDC = 6, USDT = 6, sGHO = 18
- Default slippage tolerance: 50 bps (0.5%), configurable in UI

# GHO Router for GSM

A smart contract that simplifies swapping USDC/USDT to GHO or sGHO in a single transaction for the [GSM Frontend](https://app.gsm.tokenlogic.xyz/).

- `USDC/USDT -> GHO`
- `GHO -> USDC/USDT`
- `USDC/USDT/GHO -> sGHO`

The contract lives at:

- `src/contracts/onboarding/GSMRouter.sol`

## Why this exists

Using GSM routes directly requires users/integrators to handle:

- wrapping/unwrapping through static aToken vaults
- GSM buy/sell semantics
- approval edge cases (notably USDT-style approvals)
- residual token handling on partial consumption

`GSMRouter` handles these mechanics and returns outputs directly to the caller.

## Key behavior

- Immutable route wiring at deploy time (`GSM_USDC`, `GSM_USDT`, `GHO`, `sGHO`)
- Constructor validation of route compatibility
- Slippage gates on all write paths
- Dust return events on partial consumption
- Exact approvals with `forceApprove(..., 0)` cleanup
- Preview methods for quote UX

## Public API

- `swapToGHO(address token, uint256 amount, uint256 minGHOAmount) -> uint256`
- `swapFromGHO(address token, uint256 ghoAmount, uint256 minOutputAmount) -> uint256`
- `swapTosGHO(address token, uint256 amount, uint256 minOut) -> uint256`
- `swapFromsGHO(address token, uint256 amount, uint256 minOut) -> uint256`
- `previewSwapToGHO(address token, uint256 amount) -> (uint256 ghoAmount, uint256 fee)`
- `previewSwapFromGHO(address token, uint256 ghoAmount) -> (uint256 assetAmount, uint256 fee)`
- `previewSwapFromsGHO(address token, uint256 amount) -> (uint256 outputAmount, uint256 fee)`
- `rescueToken(address token, address to, uint256 amount)` (`onlyOwner`)

See interface for events/errors:

- `src/interfaces/onboarding/IGSMRouter.sol`

## Mainnet dependencies

Configured in `script/DeployGSMRouter.s.sol`:

- GHO: [`0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f`](https://etherscan.io/address/0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f)
- sGHO (To be deployed): [`0x0000000000000000000000000000000000000000`](https://etherscan.io/address/0x0000000000000000000000000000000000000000)
- GSM USDC: [`0xFeeb6FE430B7523fEF2a38327241eE7153779535`](https://etherscan.io/address/0xFeeb6FE430B7523fEF2a38327241eE7153779535)
- GSM USDT: [`0x535b2f7C20B9C83d70e519cf9991578eF9816B7B`](https://etherscan.io/address/0x535b2f7C20B9C83d70e519cf9991578eF9816B7B)
- USDC: [`0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`](https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)
- USDT: [`0xdAC17F958D2ee523a2206206994597C13D831ec7`](https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7)
- stataUSDC: [`0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E`](https://etherscan.io/address/0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E)
- stataUSDT: [`0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8`](https://etherscan.io/address/0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8)

## Setup

```bash
forge install
forge build
```

Create env file:

```bash
cp .env.example .env
```

Expected env vars:

- `PRIVATE_KEY`
- `RPC_URL_MAINNET`
- `ETHERSCAN_API_KEY`

## Testing

Run full suite:

```bash
forge test
```

Run unit onboarding tests:

```bash
forge test --match-path test/unit/onboarding/* -vvv
```

Run fork onboarding tests (mainnet RPC required):

```bash
forge test --match-path test/fork/onboarding/GSMRouterTest.t.sol --fork-url "$RPC_URL_MAINNET" -vvv
```

## Deployment

Build and deploy with verification:

```bash
forge script script/DeployGSMRouter.s.sol:DeployGSMRouter \
  --rpc-url mainnet \
  --broadcast \
  --verify \
  -vvv
```

## Security

Status: not yet audited.

Security assumptions and failure modes are documented in:

- `SECURITY_ASSUMPTIONS.md`

Notable operational points:

- Downstream GSM/staticAToken/sGHO dependencies can change independently.
- Preview outputs are estimates, not execution guarantees.
- Integrators should monitor `DustReturned` events and set conservative slippage bounds.

## Repository layout

```text
src/
  contracts/onboarding/GSMRouter.sol
  interfaces/IGSM.sol
  interfaces/IStaticAToken.sol
  interfaces/onboarding/IGSMRouter.sol
script/
  DeployGSMRouter.s.sol
test/
  unit/onboarding/GSMRouterTest.t.sol
  unit/onboarding/GSMRouterSwapTosGHOTest.t.sol
  unit/onboarding/GSMRouterAdvancedTest.t.sol
  fork/onboarding/GSMRouterTest.t.sol
```

## License

MIT

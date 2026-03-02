# GHO Router for GSM

`GhoRouter` is a stateless swap router for GSM routes plus direct `GHO <-> sGHO`.

Supported flows:
- GSM underlying/static aToken -> GHO
- GHO -> GSM underlying/static aToken
- GSM underlying/static aToken -> sGHO
- GHO -> sGHO (direct)
- sGHO -> GSM underlying/static aToken
- sGHO -> GHO (direct)

Contract path:
- `src/GhoRouter.sol`

Interface paths:
- `src/interfaces/IGhoRouter.sol`
- `src/interfaces/IGSM.sol`
- `src/interfaces/IStaticAToken.sol`

## How routing works today

- `GHO` and `sGHO` are immutable constructor params.
- GSM routes are selected per call (`address gsm`).
- GSM swap paths are gated by `mapping(address => bool) public isGsmAllowed`.
- Direct `GHO <-> sGHO` paths use dedicated overloads without a `gsm` argument.

### `isGsmAllowed` details

- Storage: `mapping(address => bool) public isGsmAllowed`.
- Admin: `setGsmAllowed(address gsm, bool allowed)` is `onlyOwner`.
- Event: `GsmAllowedUpdated(gsm, allowed)` is emitted on updates.
- Enforcement:
  - All GSM swap overloads (`swapToGHO`, `swapFromGHO`, `swapTosGHO(gsm,...)`, `swapFromsGHO(gsm,...)`) require `isGsmAllowed[gsm] == true`.
  - Direct `GHO <-> sGHO` overloads do not use allowlist checks.
- Preview caveat: preview methods do not check `isGsmAllowed`.

### Token selection on GSM paths

- For `swapToGHO` and `swapTosGHO`, `token` is the input token and must be the GSM underlying token or its static aToken.
- For token-aware `swapFromGHO` and `swapFromsGHO`, `token` is the output token and must be the GSM underlying token or its static aToken.
- Overloads without a `token` argument default to the GSM underlying token on output paths.

## Setup

```bash
forge install
forge build
```

Optional env file:

```bash
cp .env.example .env
```

Used by current config:
- `RPC_MAINNET` (for fork tests / `vm.rpcUrl("mainnet")`)
- `ETHERSCAN_API_KEY` (only if you verify contracts)

## Testing

Run all tests:

```bash
forge test
```

Run fork tests only (requires `RPC_MAINNET`):

```bash
forge test --match-path test/fork/GhoRouter.t.sol -vvv
```

List tests in the fork suite:

```bash
forge test --match-path test/fork/GhoRouter.t.sol --list
```

## Mainnet references used in fork tests

- GHO: [`0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f`](https://etherscan.io/address/0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f)

- GSM USDC: [`0xFeeb6FE430B7523fEF2a38327241eE7153779535`](https://etherscan.io/address/0xFeeb6FE430B7523fEF2a38327241eE7153779535)
- USDC: [`0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`](https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)
- StataUSDC: [`0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E`](https://etherscan.io/address/0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E)

- GSM USDT: [`0x535b2f7C20B9C83d70e519cf9991578eF9816B7B`](https://etherscan.io/address/0x535b2f7C20B9C83d70e519cf9991578eF9816B7B)
- USDT: [`0xdAC17F958D2ee523a2206206994597C13D831ec7`](https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7)
- StataUSDT: [`0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8`](https://etherscan.io/address/0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8)

## Security

Status: not yet audited.

Security assumptions and failure modes are documented in:
- `SECURITY_ASSUMPTIONS.md`


## License

MIT

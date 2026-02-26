# GHO Router for GSM

`GSMRouter` is a stateless swap router for GSM routes plus sGHO.

Supported flows:
- GSM underlying -> GHO
- GHO -> GSM underlying
- GSM underlying or GHO -> sGHO
- sGHO -> GHO or GSM underlying

Contract path:
- `src/GSMRouter.sol`

Interface paths:
- `src/interfaces/IGSMRouter.sol`
- `src/interfaces/IGSM.sol`
- `src/interfaces/IStaticAToken.sol`

## How routing works today

- Only `GHO` and `sGHO` are immutable constructor params.
- The GSM route is provided per call (`address gsm`).
- Swap paths are gated by `mapping(address => bool) public gsmAllowed`.
- Each call validates `gsm` at runtime via `_getTokensFromGsm`:
  - `gsm` must be a contract
  - `IGSM(gsm).GHO_TOKEN()` must match router `GHO`
  - `IGSM(gsm).UNDERLYING_ASSET()` must return a non-zero static aToken
  - `IStaticAToken(asset).asset()` must return a non-zero underlying token

### `gsmAllowed` details

- Storage: `mapping(address => bool) public gsmAllowed`.
- Admin: `setGsmAllowed(address gsm, bool allowed)` is `onlyOwner`.
- Validation in `setGsmAllowed`:
  - `gsm` cannot be `address(0)`.
  - When `allowed == true`, `gsm` must have bytecode (`gsm.code.length != 0`).
- Event: `GsmAllowedUpdated(gsm, allowed)` is emitted on updates.
- Enforcement:
  - `swapToGHO` and `swapFromGHO` require `gsmAllowed[gsm] == true`.
  - `swapTosGHO` and `swapFromsGHO` require allowlisted `gsm` only when `gsm != address(0)`.
  - Direct `GHO <-> sGHO` path (`gsm == address(0)`) is intentionally allowed for those two methods.
- Current behavior: preview methods do not check `gsmAllowed`; they only run route/interface validation.

## Public API

- `swapToGHO(address gsm, uint256 amount, uint256 minGHOAmount) -> uint256`
- `swapFromGHO(address gsm, uint256 ghoAmount, uint256 minOutputAmount) -> uint256`
- `swapTosGHO(address gsm, uint256 amount, uint256 minSGHOAmount) -> uint256`
- `swapFromsGHO(address gsm, uint256 sghoAmount, uint256 minOutputAmount) -> uint256`
- `setGsmAllowed(address gsm, bool allowed)` (`onlyOwner`)
- `previewSwapToGHO(address gsm, uint256 amount) -> (uint256 ghoAmount, uint256 fee)`
- `previewSwapFromGHO(address gsm, uint256 ghoAmount) -> (uint256 assetAmount, uint256 fee)`
- `previewSwapTosGHO(address gsm, uint256 amount) -> (uint256 sghoAmount, uint256 fee)`
- `previewSwapFromsGHO(address gsm, uint256 sghoAmount) -> (uint256 outputAmount, uint256 fee)`
- `gsmAllowed(address gsm) -> bool`
- `rescueToken(address token, address to, uint256 amount)` (`onlyOwner`)

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
forge test --match-path test/fork/GSMRouter.t.sol -vvv
```

## Deployment

This repository currently does not include a checked-in deployment script under `script/`.

Constructor:
- `constructor(address owner, address gho, address sgho)`

## Mainnet references used in fork tests

- GHO: [`0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f`](https://etherscan.io/address/0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f)
- GSM USDC: [`0xFeeb6FE430B7523fEF2a38327241eE7153779535`](https://etherscan.io/address/0xFeeb6FE430B7523fEF2a38327241eE7153779535)
- GSM USDT: [`0x535b2f7C20B9C83d70e519cf9991578eF9816B7B`](https://etherscan.io/address/0x535b2f7C20B9C83d70e519cf9991578eF9816B7B)
- USDC: [`0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`](https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)
- USDT: [`0xdAC17F958D2ee523a2206206994597C13D831ec7`](https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7)

## Security

Status: not yet audited.

Security assumptions and failure modes are documented in:
- `SECURITY_ASSUMPTIONS.md`

## Repository layout

```text
src/
  GSMRouter.sol
  interfaces/
    IGSM.sol
    IGSMRouter.sol
    IStaticAToken.sol
    IsGho.sol
test/
  fork/
    GSMRouter.t.sol
    mocks/sGho.sol
```

## License

MIT

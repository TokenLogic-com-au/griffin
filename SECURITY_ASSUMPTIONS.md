# GSMRouter Failure Modes and Security Assumptions

This document captures failure modes and trust assumptions for the current
`GSMRouter` implementation at:

- `src/contracts/onboarding/GSMRouter.sol`

It is intended for integrators, operators, and reviewers.

## Scope and trust boundary

`GSMRouter` orchestrates four flows:

- `swapToGHO(token, amount, minGHOAmount)` for routed underlying -> GHO
- `swapFromGHO(token, ghoAmount, minOutputAmount)` for GHO -> routed underlying
- `swapTosGHO(token, amount, minOut)` for routed underlying or GHO -> sGHO shares
- `swapFromsGHO(token, amount, minOut)` for sGHO shares -> routed underlying or GHO

The router depends on external contracts for pricing, liquidity, and settlement:

- Two GSM routes (`GSM_USDC`, `GSM_USDT`)
- Their underlying `staticAToken` wrappers
- `sGHO` ERC4626 vault (for `swapTosGHO` and `swapFromsGHO`)
- ERC20 tokens (GHO and route underlyings)

The router keeps no per-user accounting state. It is a transient orchestration layer.

## Deployment-time validation and immutable routing

At deployment, the router validates:

- Non-zero `gho`, `sgho`, and both GSM addresses
- Distinct GSM addresses (`gsmUsdc != gsmUsdt`)
- `IERC4626(sGHO).asset() == GHO`
- For each GSM:
  - Address has bytecode
  - `GHO_TOKEN() == GHO`
  - `UNDERLYING_ASSET()` returns a non-zero `staticAToken`
  - `IStaticAToken(asset).asset()` returns a non-zero underlying token
- The two discovered underlying tokens are distinct

After these checks, routes are cached in immutables. The router does not re-discover
or re-validate route wiring on each swap call.

## Security properties in the current implementation

- Output accounting is balance-delta based:
  - `swapToGHO` derives GHO out from actual GHO balance increase
  - `swapFromGHO` derives GHO burned / stata received from balance deltas
  - `swapTosGHO` derives GHO routed to sGHO from balance deltas
  - `swapFromsGHO` derives redeemed GHO from sGHO and routed output from balance deltas
- Partial consumption handling returns residual value via `DustReturned`
- Exact approvals are used and reset to zero via `forceApprove`
- Slippage checks enforce minimum outputs:
  - `minGHOAmount`, `minOutputAmount`, `minOut`
- `rescueToken` is `onlyOwner`

These controls reduce common integration risk but do not remove dependency risk.

## Documented failure modes

### 1) Downstream dependency outage or pause

What can happen:
- Swaps revert if GSM/staticAToken/sGHO/token contracts are paused, insolvent, or revert.

Why:
- Router delegates execution to downstream protocols.

Impact:
- Route temporarily or permanently unavailable.

Current mitigation:
- Fail-fast revert behavior.
- Integrator/operator monitoring and route-level circuit breaking.

### 2) Dependency behavior drift after deployment

What can happen:
- Swaps revert or produce unexpected economics if GSM/staticAToken/sGHO behavior changes.

Why:
- Route addresses are immutable after constructor checks; runtime wiring is not re-validated.

Impact:
- Degraded pricing, broken execution, or route shutdown.

Current mitigation:
- Strict constructor validation.
- Operational monitoring and redeployment when dependencies materially change.

### 3) GSM capacity and partial consumption

What can happen:
- GSM may consume less than provided amount or fail due to insufficient capacity.

Why:
- Capacity and matching logic are external to router logic.

Impact:
- Lower output, dust returns, or revert.

Current mitigation:
- Dust return logic (`DustReturned`).
- Slippage checks on final outputs.

### 4) Quote staleness and dynamic fees/exchange rates

What can happen:
- `previewSwapToGHO` / `previewSwapFromGHO` / `previewSwapFromsGHO` values differ
  from write-call outcomes.

Why:
- Fees, liquidity state, and exchange rates can move between preview and execution.

Impact:
- Output mismatch or `SlippageExceeded` on tight minima.

Current mitigation:
- Slippage enforcement at execution.
- Integrators should add safety buffers to minima.

### 5) sGHO share-price movement and redeem-path effects

What can happen:
- `swapTosGHO` may mint fewer shares than expected.
- `swapFromsGHO` may redeem into fewer/more GHO than expected.
- For `swapFromsGHO(..., USDC/USDT, ...)`, final routed output can also vary due to GSM
  fee/capacity at execution time.

Why:
- ERC4626 share/asset conversion changes with vault state.

Impact:
- Lower share output or revert when `minOut` is too tight.

Current mitigation:
- `minOut` slippage gate.
- GHO residual return if vault consumes less than expected.
- Integrators should treat `previewSwapFromsGHO` as indicative and set conservative `minOut`.

### 6) Non-standard token behavior

What can happen:
- Fee-on-transfer, rebasing, or incompatible ERC20 behavior can break assumptions.

Why:
- Router assumes standard transfer/approval semantics for supported assets and wrappers.

Impact:
- Reverts or unexpected settlement.

Current mitigation:
- `SafeERC20` and `forceApprove` patterns.
- Restrict integration to known-compatible assets/contracts.

### 7) Owner rescue authority

What can happen:
- Owner can withdraw any ERC20 held by router using `rescueToken`.

Why:
- Administrative recovery function is intentionally broad.

Impact:
- Centralization / key-management risk.

Current mitigation:
- Use trusted ownership (preferably multisig/governance) and monitor rescue actions.

## Security assumptions

The current design assumes:

1. GSM, staticAToken, sGHO, and token dependencies are non-malicious and interface-compatible.
2. Supported routes maintain sufficient liquidity/capacity for intended trade sizes.
3. Integrators/users set realistic slippage bounds for write calls.
4. Downstream upgrades, pauses, and parameter changes are actively monitored.
5. Router ownership is trusted to use `rescueToken` only for operational recovery.
6. Preview functions are treated as estimates, not execution guarantees.
7. `sGHO` `previewRedeem` and `redeem` semantics remain ERC4626-compatible over time.

## Explicit dependency map

- `swapToGHO`: underlying token -> staticAToken deposit -> GSM sell -> GHO transfer
- `swapFromGHO`: GHO -> GSM buy -> staticAToken redeem -> underlying transfer
- `swapTosGHO`:
  - direct path: GHO -> sGHO deposit
  - routed path: underlying -> staticAToken -> GSM -> GHO -> sGHO
- `swapFromsGHO`:
  - direct path: sGHO redeem -> GHO transfer
  - routed path: sGHO redeem -> GHO -> GSM buy -> staticAToken redeem -> underlying transfer

Any incident or semantic change in these dependencies can change outcomes.

## Integrator guidance

1. Quote close to execution and include conservative slippage buffers.
2. Track `DustReturned` events and reconcile consumed vs requested amounts.
3. Surface custom errors (`InvalidGsm`, `InvalidToken`, `InvalidAmount`, `SlippageExceeded`, `ZeroAddress`).
4. Monitor downstream governance/upgrade/pause events and disable routes on anomaly.
5. Treat fork/invariant tests as smoke coverage, not complete economic assurance.

# GSMRouter Failure Modes and Security Assumptions

This document defines expected failure modes and trust assumptions for:

- `GSMRouter` (`src/contracts/onboarding/GSMRouter.sol`)

It is intended for integrators, operators, and reviewers.

## Scope and trust boundary

`GSMRouter` is an orchestration layer for:

- `swapToGHO` (USDC/USDT -> GHO via GSM)
- `swapFromGHO` (GHO -> USDC/USDT via GSM)
- `swapTosGHO` (USDC/USDT/GHO -> sGHO shares)

It relies on external contracts for pricing, liquidity, accounting, and settlement:

- `GSM` contracts (`GSM_USDC`, `GSM_USDT`)
- `staticAToken` wrappers used by each GSM
- `sGHO` (ERC4626 vault) for `swapTosGHO`
- ERC20 tokens (`GHO`, `USDC`, `USDT`)

The router does not maintain user accounting balances and uses exact approvals per call.

## Documented failure modes

### 1) sGHO yield variance / share-price drift

What can happen:
- `swapTosGHO` share output can vary from user expectations due to ERC4626 exchange-rate movement.

Why:
- `sGHO` share/asset conversion changes over time with yield accrual.

Impact:
- Fewer shares than anticipated if `minOut` is too strict.

Current mitigation:
- Slippage check (`SlippageExceeded`) on `swapTosGHO`.
- Integrator should set risk-adjusted `minOut`.

### 2) GSM liquidity issues (capacity and partial consumption)

What can happen:
- Swaps can fail if GSM capacity is insufficient.
- GSM may consume only part of provided amount.

Why:
- Capacity and execution semantics are external to router logic.

Impact:
- Revert or partial fill with returned residual value.

Current mitigation:
- Slippage guards (`SlippageExceeded`).
- Dust forwarding (`DustReturned`) for unconsumed value.

### 3) Dynamic GSM fees

What can happen:
- Effective output can change between quote and execution.
- On reverse flows, not all provided GHO may be burned, creating GHO dust.

Why:
- Fees and effective execution are determined by current GSM state.

Impact:
- Quote/execution mismatch and potential revert under tight minima.

Current mitigation:
- Live GSM reads at execution.
- Slippage enforcement on writes.
- Dust forwarded back to caller.

### 4) Dependency failure / config mismatch

What can happen:
- Runtime reverts if GSM/vault addresses are invalid or incompatible.

Why:
- Router validates contract wiring at call time (`InvalidGsm`, `InvalidToken`) but cannot prevent dependency behavior changes.

Impact:
- Operational failures for affected routes.

Current mitigation:
- Call-time checks for GSM `GHO_TOKEN`, `UNDERLYING_ASSET`, and `staticAToken.asset()`.
- Constructor-time check that immutable `SGHO` vault has `asset() == GHO`.

### 5) Preview staleness

What can happen:
- UI preview differs from settled output.

Why:
- Previews are read-only snapshots; state can move before inclusion.

Impact:
- Unexpected output or revert with tight slippage.

Current mitigation:
- Slippage bounds in write calls.
- Integrator should apply safety buffers.

### 6) Token standard deviations and approval edge cases

What can happen:
- Non-standard ERC20 approval behavior can break naive flows.

Why:
- Tokens like USDT require force-approve patterns.

Impact:
- Approval-related revert risk if integrations copy unsafe patterns.

Current mitigation:
- Router uses `SafeERC20` + `forceApprove` reset-to-zero patterns.

## Security assumptions

The design assumes:

1. External dependencies (`GSM`, `staticAToken`, `sGHO`, ERC20s) are non-malicious and interface-compatible.
2. External liquidity/capacity exists for intended trade sizes.
3. Users/integrators provide realistic slippage bounds (`minGHOAmount`, `minOutputAmount`, `minOut`).
4. Governance/admin changes on downstream protocols are monitored.
5. `GSMRouter` owner uses `rescueToken` only for recovery of stranded funds.
6. Integrators treat preview values as estimates, not guarantees.

## Explicit downstream dependencies

Critical runtime dependencies:

- `GSMRouter` -> selected `GSM`, derived `staticAToken`, underlying ERC20
- `swapTosGHO` path -> `sGHO` vault with `asset() == GHO`
- `GSM` -> fee logic, capacity, pricing, and burn/mint behavior
- `staticAToken` -> deposit/redeem exchange-rate mechanics

Any upgrade, pause, parameter change, or incident in these dependencies can impact outcomes.

## Integrator guidance

1. Set slippage thresholds from fresh previews with safety margin.
2. Surface and track `DustReturned` events in UX and analytics.
3. Decode and surface custom errors (`InvalidGsm`, `InvalidToken`, `SlippageExceeded`, `ZeroAddress`).
4. Monitor GSM fee/capacity parameters and disable affected routes on anomaly.
5. Treat fork tests as integration smoke coverage, not exhaustive economic guarantees.

# GSMRouter Failure Modes and Security Assumptions

This document captures trust assumptions and failure modes for the current
router implementation at:

- `src/GSMRouter.sol`

It is intended for integrators, operators, and reviewers.

## Scope and trust boundary

`GSMRouter` orchestrates four flows:

- `swapToGHO(gsm, amount, minGHOAmount)` for GSM underlying -> GHO
- `swapFromGHO(gsm, ghoAmount, minOutputAmount)` for GHO -> GSM underlying
- `swapTosGHO(gsm, amount, minSGHOAmount)` for GSM underlying or GHO -> sGHO (in which case you pass zero address for gsm)
- `swapFromsGHO(gsm, sghoAmount, minOutputAmount)` for sGHO -> GSM underlying or GHO (in which case you pass zero address for gsm)

Important shape of the current design:

- `GHO` and `sGHO` are immutable constructor params.
- `gsm` is caller-supplied on each swap/preview call.
- Swap routes are gated by on-chain allowlist state in `gsmAllowed`.
- The router keeps no per-user accounting state.

## Runtime route validation

For non-zero `gsm`, `_getTokensFromGsm` validates on each call:

- `gsm != address(0)` and `gsm.code.length != 0`
- `IGSM(gsm).GHO_TOKEN() == GHO`
- `IGSM(gsm).UNDERLYING_ASSET()` returns non-zero `stataToken`
- `IStaticAToken(stataToken).asset()` returns non-zero underlying token

This means routing is dynamic at runtime, not fixed at deployment.

## GSM Allowlist (`gsmAllowed`)

- Storage: `mapping(address => bool) public gsmAllowed`.
- Update path: `setGsmAllowed(address gsm, bool allowed)` (`onlyOwner`).
- Update constraints:
  - `gsm != address(0)` always.
  - Enabling (`allowed = true`) requires `gsm.code.length != 0`.
- Swap enforcement:
  - `swapToGHO` and `swapFromGHO` always require `gsmAllowed[gsm] == true`.
  - `swapTosGHO` and `swapFromsGHO` require allowlisted `gsm` only when `gsm != address(0)`.
  - Direct `GHO <-> sGHO` path (`gsm == address(0)`) bypasses allowlist checks by design.
- Observability: `GsmAllowedUpdated(gsm, allowed)` is emitted on every update.
- Important caveat: preview methods do not enforce `gsmAllowed`; they only perform route/interface validation.

## Security assumptions

The current implementation assumes:

1. Owner securely manages `gsmAllowed` and curates safe GSM addresses.
2. `IGSM` and `IStaticAToken` dependencies are interface-compatible and non-malicious.
3. `sGHO` is a valid ERC4626 vault over GHO (constructor does not enforce `asset() == GHO`).
4. External dependency return values are correct (router accounting uses returned values).
5. Underlying tokens involved in selected routes have ERC20 semantics compatible with `SafeERC20`.
6. Users/integrators set realistic slippage bounds.
7. Owner key management is trusted for `rescueToken`.

## Security properties in the current implementation

- Slippage checks are enforced on all write flows:
  - `minGHOAmount`, `minOutputAmount`, `minSGHOAmount`
- Swap calls (except direct `gsm == address(0)` sGHO paths) are gated by `gsmAllowed`.
- Partial-consumption dust handling is present for GSM buy/sell paths:
  - Underlying dust returned on `_sellUnderlyingForGho`
  - GHO dust returned on `_buyUnderlyingWithGho`
  - `DustReturned` is emitted
- Approvals are exact and cleaned up for GSM/sGHO spenders:
  - `GHO -> gsm` is zeroed after `buyAsset`
  - `stataToken -> gsm` is zeroed after `sellAsset`
  - `GHO -> sGHO` is zeroed after `deposit`
- `rescueToken` is `onlyOwner`

Limitations of current implementation:

- No internal pause/circuit-breaker.
- No explicit reentrancy guard.
- Input-token approval to `stataToken` in `_sellUnderlyingForGho` is not reset to zero.
- Preview methods can return quotes for non-allowlisted GSMs.

## Documented failure modes

### 1) Dependency outage, pause, or insolvency

What can happen:
- Swaps revert or settle unexpectedly if GSM/static aToken/sGHO/token dependencies fail.

Why:
- Router delegates pricing/settlement to external contracts.

Impact:
- Route unavailable or economically unsafe.

Current mitigation:
- Fail-fast reverts.
- External monitoring and route-level disabling by integrators/operators.

### 2) GSM allowlist misconfiguration or admin compromise

What can happen:
- Valid routes can be unintentionally disabled, or unsafe routes can be enabled.

Why:
- Allowlist changes are owner-controlled via `setGsmAllowed`.

Impact:
- Route outage or exposure to undesired GSM risk.

Current mitigation:
- `onlyOwner` protection on updates.
- `GsmAllowedUpdated` event monitoring and operational controls around ownership.

### 3) Runtime route composition drift

What can happen:
- A previously acceptable `gsm` can begin routing to different components over time.

Why:
- Router re-reads `UNDERLYING_ASSET()` and `asset()` at runtime on every call.

Impact:
- Route behavior can change without router redeploy.

Current mitigation:
- Operational monitoring of downstream config/governance changes.
- Owner-managed allowlist/circuit-breaker controls.

### 4) Preview/allowlist mismatch and quote staleness

What can happen:
- Preview calls can succeed for a GSM that later reverts on swap due to `GsmNotAllowed`.
- Preview outputs can also differ from write-call outcomes due to dynamic fees/rates.

Why:
- Preview methods do not enforce `gsmAllowed`.
- GSM fee/capacity and vault exchange rates can change between preview and execution.

Impact:
- Quote UX mismatch, `GsmNotAllowed` revert, lower output, or `SlippageExceeded` revert.

Current mitigation:
- Execution-time minimum output checks.
- Conservative slippage buffers by integrators/users.
- Integrators should check `gsmAllowed(gsm)` before swap submission.

### 5) GSM capacity and partial consumption

What can happen:
- GSM may consume less than requested input or requested GHO budget.

Why:
- Capacity/matching are external.

Impact:
- Dust returns and lower-than-requested fill.

Current mitigation:
- Dust-return logic plus `DustReturned` event.
- Slippage minimums.

### 6) sGHO compatibility / misconfiguration risk

What can happen:
- `swapTosGHO`/`swapFromsGHO` may revert or behave unexpectedly.

Why:
- Constructor only checks `sgho != address(0)`; it does not enforce ERC4626 asset compatibility.

Impact:
- Broken path or fund loss if deployed with the wrong vault.

Current mitigation:
- Deployment hygiene and post-deploy verification.

### 7) Non-standard token behavior

What can happen:
- Fee-on-transfer/rebasing/non-standard approval semantics can break path assumptions.

Why:
- Router assumes compatible ERC20 transfer/approval behavior along selected routes.

Impact:
- Reverts or unexpected settlement.

Current mitigation:
- `SafeERC20`/`forceApprove` usage.
- Restrict routes to known-compatible assets.

### 8) Residual allowance and stranded-fund risk

What can happen:
- If tokens are stranded in router, previously granted allowance to `stataToken` may be spendable.

Why:
- Input token approval to `stataToken` is set per call but not explicitly reset to zero.

Impact:
- Recovery complexity or potential token pull by approved spender, depending on token semantics.

Current mitigation:
- Keep router stateless operationally and monitor balances.
- Use `rescueToken` governance process for recovery.

### 9) Owner rescue authority

What can happen:
- Owner can withdraw any ERC20 held by router using `rescueToken`.

Why:
- Function is intentionally broad for operational recovery.

Impact:
- Centralization/key-management risk.

Current mitigation:
- Use trusted ownership (preferably multisig/governance) and monitor rescue actions.

## Integrator guidance

1. Monitor `GsmAllowedUpdated` and verify `gsmAllowed(gsm)` before submitting swaps.
2. Quote immediately before execution and set conservative minimum outputs.
3. Monitor `DustReturned` events and reconcile requested vs consumed amounts.
4. Alert on downstream upgrades/pauses/parameter changes for GSM/static aToken/sGHO.
5. Treat fork tests as integration smoke tests, not full economic assurance.

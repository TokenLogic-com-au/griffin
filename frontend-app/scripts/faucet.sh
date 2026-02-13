#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# sGHO Router Local Faucet
# ============================================================================
# Drips test tokens on an Anvil fork of Ethereum mainnet.
# Uses Anvil impersonation to transfer from mainnet whales.
#
# Usage:
#   ./scripts/faucet.sh <YOUR_ADDRESS> [RPC_URL]
#
# Examples:
#   ./scripts/faucet.sh 0xYourAddress
#   ./scripts/faucet.sh 0xYourAddress http://127.0.0.1:8545
#
# Tokens dripped:
#   - 100 ETH   (gas)
#   - 100,000 USDC
#   - 100,000 USDT
#   - 100,000 GHO
#   - 50,000 sGHO  (deposits GHO into sGHO vault)
# ============================================================================

RECIPIENT="${1:?Usage: ./scripts/faucet.sh <ADDRESS> [RPC_URL]}"
RPC="${2:-http://127.0.0.1:8545}"

# --------------- Token Addresses (Ethereum Mainnet) ---------------
GHO="0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f"
USDC="0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
USDT="0xdAC17F958D2ee523a2206206994597C13D831ec7"

# sGHO vault address -- set via env or leave empty to skip sGHO minting
SGHO="${NEXT_PUBLIC_SGHO_ADDRESS:-}"

# --------------- Whale Addresses ---------------
# These addresses hold large balances on mainnet and will be impersonated.
BINANCE_14="0x28C6c06298d514Db089934071355E5743bf21d60"   # USDC + USDT
AAVE_COLLECTOR="0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c" # GHO (Aave Treasury)

# Fallback GHO whales in case the primary doesn't have enough
GHO_WHALE_2="0x4aa42145Aa6Ebf72e164C9bBC74fbD3788045016"  # known GHO holder

# --------------- Amounts ---------------
ETH_AMOUNT="100ether"
USDC_AMOUNT="100000000000"   # 100,000 USDC  (6 decimals)
USDT_AMOUNT="100000000000"   # 100,000 USDT  (6 decimals)
GHO_AMOUNT="100000000000000000000000"  # 100,000 GHO (18 decimals)
SGHO_DEPOSIT="50000000000000000000000"  # 50,000 GHO -> sGHO (18 decimals)

# --------------- Helpers ---------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[!!]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }

check_balance() {
  local token="$1" holder="$2" label="$3"
  local bal
  bal=$(cast call "$token" "balanceOf(address)(uint256)" "$holder" --rpc-url "$RPC" 2>/dev/null || echo "0")
  if [ "$bal" = "0" ]; then
    return 1
  fi
  return 0
}

drip_erc20() {
  local token="$1" whale="$2" amount="$3" label="$4"

  # Impersonate whale
  cast rpc anvil_impersonateAccount "$whale" --rpc-url "$RPC" > /dev/null 2>&1

  # Give whale some ETH for gas
  cast rpc anvil_setBalance "$whale" "0x56BC75E2D63100000" --rpc-url "$RPC" > /dev/null 2>&1

  # Transfer
  cast send "$token" "transfer(address,uint256)" "$RECIPIENT" "$amount" \
    --from "$whale" --rpc-url "$RPC" --unlocked > /dev/null 2>&1

  # Stop impersonation
  cast rpc anvil_stopImpersonatingAccount "$whale" --rpc-url "$RPC" > /dev/null 2>&1
}

# --------------- Main ---------------
echo ""
echo "======================================"
echo "  sGHO Router Local Faucet"
echo "======================================"
echo ""
echo "  Recipient: $RECIPIENT"
echo "  RPC:       $RPC"
echo ""

# 1. ETH
echo "Dripping ETH..."
cast rpc anvil_setBalance "$RECIPIENT" "0x56BC75E2D63100000" --rpc-url "$RPC" > /dev/null 2>&1
ok "100 ETH"

# 2. USDC
echo "Dripping USDC..."
if drip_erc20 "$USDC" "$BINANCE_14" "$USDC_AMOUNT" "USDC"; then
  ok "100,000 USDC"
else
  fail "Could not drip USDC (whale may not have sufficient balance on this fork)"
fi

# 3. USDT
echo "Dripping USDT..."
if drip_erc20 "$USDT" "$BINANCE_14" "$USDT_AMOUNT" "USDT"; then
  ok "100,000 USDT"
else
  fail "Could not drip USDT (whale may not have sufficient balance on this fork)"
fi

# 4. GHO
echo "Dripping GHO..."
GHO_DRIPPED=false
for whale in "$AAVE_COLLECTOR" "$GHO_WHALE_2"; do
  if check_balance "$GHO" "$whale" "GHO"; then
    if drip_erc20 "$GHO" "$whale" "$GHO_AMOUNT" "GHO"; then
      ok "100,000 GHO (from $(echo $whale | head -c 10)...)"
      GHO_DRIPPED=true
      break
    fi
  fi
done
if [ "$GHO_DRIPPED" = false ]; then
  fail "Could not drip GHO (no whale with sufficient balance found)"
fi

# 5. sGHO (optional -- deposit GHO into sGHO vault)
if [ -n "$SGHO" ] && [ "$SGHO" != "0x0000000000000000000000000000000000000000" ] && [ "$GHO_DRIPPED" = true ]; then
  echo "Minting sGHO (depositing GHO into vault)..."

  # Impersonate recipient to do the deposit
  cast rpc anvil_impersonateAccount "$RECIPIENT" --rpc-url "$RPC" > /dev/null 2>&1

  # Approve sGHO vault to spend GHO
  cast send "$GHO" "approve(address,uint256)" "$SGHO" "$SGHO_DEPOSIT" \
    --from "$RECIPIENT" --rpc-url "$RPC" --unlocked > /dev/null 2>&1

  # Deposit GHO into sGHO vault (ERC4626)
  cast send "$SGHO" "deposit(uint256,address)" "$SGHO_DEPOSIT" "$RECIPIENT" \
    --from "$RECIPIENT" --rpc-url "$RPC" --unlocked > /dev/null 2>&1

  cast rpc anvil_stopImpersonatingAccount "$RECIPIENT" --rpc-url "$RPC" > /dev/null 2>&1

  ok "~50,000 sGHO shares (deposited 50,000 GHO)"
else
  if [ -z "$SGHO" ] || [ "$SGHO" = "0x0000000000000000000000000000000000000000" ]; then
    warn "Skipping sGHO -- set NEXT_PUBLIC_SGHO_ADDRESS to enable"
  fi
fi

# --------------- Summary ---------------
echo ""
echo "Final balances:"
ETH_BAL=$(cast balance "$RECIPIENT" --rpc-url "$RPC" --ether 2>/dev/null || echo "?")
USDC_BAL=$(cast call "$USDC" "balanceOf(address)(uint256)" "$RECIPIENT" --rpc-url "$RPC" 2>/dev/null || echo "0")
USDT_BAL=$(cast call "$USDT" "balanceOf(address)(uint256)" "$RECIPIENT" --rpc-url "$RPC" 2>/dev/null || echo "0")
GHO_BAL=$(cast call "$GHO" "balanceOf(address)(uint256)" "$RECIPIENT" --rpc-url "$RPC" 2>/dev/null || echo "0")

echo "  ETH:   $ETH_BAL"
echo "  USDC:  $(echo "scale=2; $USDC_BAL / 1000000" | bc 2>/dev/null || echo "$USDC_BAL (raw)")"
echo "  USDT:  $(echo "scale=2; $USDT_BAL / 1000000" | bc 2>/dev/null || echo "$USDT_BAL (raw)")"
echo "  GHO:   $(echo "scale=2; $GHO_BAL / 1000000000000000000" | bc 2>/dev/null || echo "$GHO_BAL (raw)")"

if [ -n "$SGHO" ] && [ "$SGHO" != "0x0000000000000000000000000000000000000000" ]; then
  SGHO_BAL=$(cast call "$SGHO" "balanceOf(address)(uint256)" "$RECIPIENT" --rpc-url "$RPC" 2>/dev/null || echo "0")
  echo "  sGHO:  $(echo "scale=2; $SGHO_BAL / 1000000000000000000" | bc 2>/dev/null || echo "$SGHO_BAL (raw)")"
fi

echo ""
echo "Done! You can now test the app at http://localhost:3000"
echo ""

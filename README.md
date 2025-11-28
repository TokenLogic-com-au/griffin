# GHO Router for GSM

A smart contract that simplifies swapping USDC/USDT to GHO in a single transaction for the [GSM Frontend](https://app.gsm.tokenlogic.xyz/).

## Problem Statement

Currently, users need to perform multiple manual steps:
1. Convert USDC to stataUSDC (no frontend exists)
2. Convert stataUSDC to GHO via GSM

This creates friction because:
- stataTokens are not well-known
- Users need multiple transactions
- Complex approval management required

## Solution

GHO router provides a single-transaction flow that handles all the complexity:

```
USDC/USDT → [Router] → GHO
```

### Key Features

- ✅ **Single Transaction**: All steps bundled into one call
- ✅ **Exact Approvals**: Never requests unlimited approvals
- ✅ **No Fund Storage**: Contract never holds user funds
- ✅ **Slippage Protection**: Built-in protection against unfavorable swaps
- ✅ **Bidirectional**: Supports both deposit and withdrawal flows

## Architecture

### Forward Flow: USDC/USDT → GHO

1. User approves exact amount to GHO Router
2. Router receives tokens
3. Router supplies to Aave V3 Pool → receives aTokens
4. Router wraps aTokens → stataTokens (ERC4626)
5. Router approves exact stataTokens to GSM
6. Router calls GSM.sellAsset() → receives GHO
7. Router transfers GHO to user

### Reverse Flow: GHO → USDC/USDT

1. User approves exact GHO to GHO Router
2. Router receives GHO
3. Router calls GSM.buyAsset() → receives stataTokens
4. Router unwraps stataTokens → aTokens
5. Router withdraws from Aave → receives underlying
6. Router transfers USDC/USDT to user

## Contract Addresses (Ethereum Mainnet)

| Contract | Address |
|----------|---------|
| **GHO Router** | _To be deployed_ |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` |
| GHO | `0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f` |
| Aave V3 Pool | `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2` |
| GSM USDC | `0xFeeb6FE430B7523fEF2a38327241eE7153779535` |
| GSM USDT | `0x535b2f7C20B9C83d70e519cf9991578eF9816B7B` |
| stataUSDC | `0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E` |
| stataUSDT | `0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8` |

## Usage

### Installation

```bash
# Clone the repository
git clone https://github.com/[username]/griffin
cd griffin

# Install dependencies
forge install

# Build contracts
forge build
```

### Testing

```bash
# Run all tests
forge test

# Run tests with mainnet fork
forge test --fork-url https://eth.llamarpc.com -vvv

# Run specific test
forge test --match-test testVerifyAddresses -vv --fork-url https://eth.llamarpc.com

# Gas report
forge test --gas-report
```

### Integration Example

```solidity
import {GSMRouter} from "./src/GSMRouter.sol";
import {IERC20} from "./src/interfaces/IERC20.sol";

// Deploy router
GSMRouter router = new GSMRouter();

// Swap USDC to GHO
IERC20(USDC).approve(address(router), 1000e6);
uint256 ghoReceived = router.swapToGHO(
    USDC,           // input token
    1000e6,         // 1000 USDC (6 decimals)
    990e18          // minimum 990 GHO (1% slippage)
);

// Swap GHO back to USDC
IERC20(GHO).approve(address(router), 1000e18);
uint256 usdcReceived = router.swapFromGHO(
    USDC,           // output token
    1000e18,        // 1000 GHO
    990e6           // minimum 990 USDC
);
```

### Frontend Integration

```typescript
// TypeScript/ethers.js example
const router = new ethers.Contract(routerAddress, GSMRouterABI, signer);

// Approve USDC
const usdc = new ethers.Contract(USDC_ADDRESS, ERC20_ABI, signer);
await usdc.approve(routerAddress, amount);

// Swap to GHO
const tx = await router.swapToGHO(
  USDC_ADDRESS,
  ethers.parseUnits("1000", 6),  // 1000 USDC
  ethers.parseUnits("990", 18)   // min 990 GHO (1% slippage)
);
await tx.wait();
```

## Security

### Audit Status
⚠️ **Not audited** - External audit recommended before mainnet deployment

### Security Features

1. **Exact Approvals**: Contract only approves the exact amounts needed for each operation
2. **No Fund Storage**: Contract never stores user funds between transactions
3. **Slippage Protection**: All swaps require minimum output amounts
4. **Reentrancy Safe**: No state changes after external calls
5. **Error Handling**: Clear, descriptive error messages

### Known Considerations

- stataToken addresses need verification against production GSM contracts
- aToken addresses are hardcoded (consider dynamic lookup for flexibility)
- Gas optimization opportunities exist (consider batching)

## Development

### Project Structure

```
griffin/
├── src/
│   ├── GSMRouter.sol           # Main router contract
│   ├── Addresses.sol           # Mainnet address constants
│   └── interfaces/
│       ├── IERC20.sol
│       ├── IERC4626.sol
│       ├── IGSM.sol
│       └── IStaticAToken.sol
├── test/
│   ├── GSMRouter.t.sol         # Integration tests
├── foundry.toml                # Foundry configuration
├── README.md                   # This file
```


## Resources

- [GSM Frontend](https://app.gsm.tokenlogic.xyz/)
- [Aave V3 Documentation](https://docs.aave.com/developers/getting-started/readme)
- [GHO Documentation](https://docs.gho.xyz/)
- [Static aToken V3](https://github.com/bgd-labs/static-a-token-v3)
- [Aave Address Book](https://github.com/bgd-labs/aave-address-book)
- [Foundry Book](https://book.getfoundry.sh/)

## License

MIT

## Disclaimer

This software is provided "as is", without warranty of any kind. Use at your own risk. Always verify contract addresses and test thoroughly before using with real funds.

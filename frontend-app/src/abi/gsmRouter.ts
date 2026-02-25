export const gsmRouterAbi = [
  // -- Read --
  {
    type: "function",
    name: "GHO",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "sGHO",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "GSM_USDC",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "GSM_USDT",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "owner",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "previewSwapToGHO",
    inputs: [
      { name: "token", type: "address", internalType: "address" },
      { name: "amount", type: "uint256", internalType: "uint256" },
    ],
    outputs: [
      { name: "ghoAmount", type: "uint256", internalType: "uint256" },
      { name: "fee", type: "uint256", internalType: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "previewSwapFromGHO",
    inputs: [
      { name: "token", type: "address", internalType: "address" },
      { name: "ghoAmount", type: "uint256", internalType: "uint256" },
    ],
    outputs: [
      { name: "assetAmount", type: "uint256", internalType: "uint256" },
      { name: "fee", type: "uint256", internalType: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "previewSwapTosGHO",
    inputs: [
      { name: "token", type: "address", internalType: "address" },
      { name: "amount", type: "uint256", internalType: "uint256" },
    ],
    outputs: [
      { name: "sghoAmount", type: "uint256", internalType: "uint256" },
      { name: "fee", type: "uint256", internalType: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "previewSwapFromsGHO",
    inputs: [
      { name: "token", type: "address", internalType: "address" },
      { name: "amount", type: "uint256", internalType: "uint256" },
    ],
    outputs: [
      { name: "outputAmount", type: "uint256", internalType: "uint256" },
      { name: "fee", type: "uint256", internalType: "uint256" },
    ],
    stateMutability: "view",
  },
  // -- Write --
  {
    type: "function",
    name: "swapToGHO",
    inputs: [
      { name: "token", type: "address", internalType: "address" },
      { name: "amount", type: "uint256", internalType: "uint256" },
      { name: "minGHOAmount", type: "uint256", internalType: "uint256" },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "swapFromGHO",
    inputs: [
      { name: "token", type: "address", internalType: "address" },
      { name: "ghoAmount", type: "uint256", internalType: "uint256" },
      { name: "minOutputAmount", type: "uint256", internalType: "uint256" },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "swapTosGHO",
    inputs: [
      { name: "token", type: "address", internalType: "address" },
      { name: "amount", type: "uint256", internalType: "uint256" },
      { name: "minOut", type: "uint256", internalType: "uint256" },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "swapFromsGHO",
    inputs: [
      { name: "token", type: "address", internalType: "address" },
      { name: "amount", type: "uint256", internalType: "uint256" },
      { name: "minOut", type: "uint256", internalType: "uint256" },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "rescueToken",
    inputs: [
      { name: "token", type: "address", internalType: "address" },
      { name: "to", type: "address", internalType: "address" },
      { name: "amount", type: "uint256", internalType: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "transferOwnership",
    inputs: [{ name: "newOwner", type: "address", internalType: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "renounceOwnership",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  // -- Events --
  {
    type: "event",
    name: "SwapToGHO",
    inputs: [
      { name: "user", type: "address", indexed: true, internalType: "address" },
      { name: "inputToken", type: "address", indexed: true, internalType: "address" },
      { name: "inputAmount", type: "uint256", indexed: false, internalType: "uint256" },
      { name: "ghoAmount", type: "uint256", indexed: false, internalType: "uint256" },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "SwapFromGHO",
    inputs: [
      { name: "user", type: "address", indexed: true, internalType: "address" },
      { name: "outputToken", type: "address", indexed: true, internalType: "address" },
      { name: "ghoAmount", type: "uint256", indexed: false, internalType: "uint256" },
      { name: "outputAmount", type: "uint256", indexed: false, internalType: "uint256" },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "SwapTosGHO",
    inputs: [
      { name: "user", type: "address", indexed: true, internalType: "address" },
      { name: "inputToken", type: "address", indexed: true, internalType: "address" },
      { name: "sgho", type: "address", indexed: true, internalType: "address" },
      { name: "inputAmount", type: "uint256", indexed: false, internalType: "uint256" },
      { name: "ghoAmount", type: "uint256", indexed: false, internalType: "uint256" },
      { name: "sghoAmount", type: "uint256", indexed: false, internalType: "uint256" },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "SwapFromsGHO",
    inputs: [
      { name: "user", type: "address", indexed: true, internalType: "address" },
      { name: "sgho", type: "address", indexed: true, internalType: "address" },
      { name: "outputToken", type: "address", indexed: true, internalType: "address" },
      { name: "sghoAmount", type: "uint256", indexed: false, internalType: "uint256" },
      { name: "ghoAmount", type: "uint256", indexed: false, internalType: "uint256" },
      { name: "outputAmount", type: "uint256", indexed: false, internalType: "uint256" },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "DustReturned",
    inputs: [
      { name: "user", type: "address", indexed: true, internalType: "address" },
      { name: "token", type: "address", indexed: true, internalType: "address" },
      { name: "amount", type: "uint256", indexed: false, internalType: "uint256" },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "OwnershipTransferred",
    inputs: [
      { name: "previousOwner", type: "address", indexed: true, internalType: "address" },
      { name: "newOwner", type: "address", indexed: true, internalType: "address" },
    ],
    anonymous: false,
  },
  // -- Errors --
  { type: "error", name: "InvalidGsm", inputs: [] },
  { type: "error", name: "InvalidToken", inputs: [] },
  { type: "error", name: "InvalidAmount", inputs: [] },
  { type: "error", name: "SlippageExceeded", inputs: [] },
  { type: "error", name: "ZeroAddress", inputs: [] },
  {
    type: "error",
    name: "OwnableInvalidOwner",
    inputs: [{ name: "owner", type: "address", internalType: "address" }],
  },
  {
    type: "error",
    name: "OwnableUnauthorizedAccount",
    inputs: [{ name: "account", type: "address", internalType: "address" }],
  },
  {
    type: "error",
    name: "SafeERC20FailedOperation",
    inputs: [{ name: "token", type: "address", internalType: "address" }],
  },
] as const;

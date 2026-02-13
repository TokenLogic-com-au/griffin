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
    name: "previewSwapToGHO",
    inputs: [
      { name: "gsm", type: "address", internalType: "address" },
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
      { name: "gsm", type: "address", internalType: "address" },
      { name: "ghoAmount", type: "uint256", internalType: "uint256" },
    ],
    outputs: [
      { name: "assetAmount", type: "uint256", internalType: "uint256" },
      { name: "fee", type: "uint256", internalType: "uint256" },
    ],
    stateMutability: "view",
  },
  // -- Write --
  {
    type: "function",
    name: "swapToGHO",
    inputs: [
      { name: "gsm", type: "address", internalType: "address" },
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
      { name: "gsm", type: "address", internalType: "address" },
      { name: "ghoAmount", type: "uint256", internalType: "uint256" },
      { name: "minOutputAmount", type: "uint256", internalType: "uint256" },
    ],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
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
    name: "DustReturned",
    inputs: [
      { name: "user", type: "address", indexed: true, internalType: "address" },
      { name: "token", type: "address", indexed: true, internalType: "address" },
      { name: "amount", type: "uint256", indexed: false, internalType: "uint256" },
    ],
    anonymous: false,
  },
  // -- Errors --
  { type: "error", name: "InvalidGsm", inputs: [] },
  { type: "error", name: "InvalidToken", inputs: [] },
  { type: "error", name: "InvalidAmount", inputs: [] },
  { type: "error", name: "SlippageExceeded", inputs: [] },
  { type: "error", name: "ZeroAddress", inputs: [] },
] as const;

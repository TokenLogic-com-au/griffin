export const ghoAbi = [
  {
    type: "function",
    name: "getFacilitatorBucket",
    inputs: [{ name: "facilitator", type: "address", internalType: "address" }],
    outputs: [
      { name: "bucketCapacity", type: "uint128", internalType: "uint128" },
      { name: "bucketLevel", type: "uint128", internalType: "uint128" },
    ],
    stateMutability: "view",
  },
] as const;

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

library Addresses {
    // Tokens
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    // Aave V3
    address internal constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    // GHO Ecosystem
    address internal constant STAKED_GHO = 0x1a88Df1cFe15Af22B3c4c783D4e6F7F9e0C1885d;

    // Static aTokens - ERC4626 wrappers for Aave aTokens
    // Based on https://github.com/bgd-labs/static-a-token-v3
    address internal constant STATA_USDC = 0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E; // waEthUSDC
    address internal constant STATA_USDT = 0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8; // waEthUSDT

    // GSM Contracts - GHO Stability Modules
    address internal constant GSM_USDC = 0xFeeb6FE430B7523fEF2a38327241eE7153779535; // Gsm4626 USDC
    address internal constant GSM_USDT = 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B; // Gsm4626 USDT
}

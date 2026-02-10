// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console2} from "forge-std/Script.sol";

import {SGHORouter} from "src/contracts/onboarding/SGHORouter.sol";

/**
 * @title DeploySGHORouter
 * @notice Deployment script for SGHORouter
 * @dev Required env:
 *      - PRIVATE_KEY
 *      - SGHO
 *      - GSM_ROUTER
 * @dev Optional env (defaults to mainnet):
 *      - GHO
 *      - USDC
 *      - USDT
 *      - GSM_USDC
 *      - GSM_USDT
 * @dev Run with:
 *      forge script script/DeploySGHORouter.s.sol --rpc-url mainnet --broadcast --verify -vv
 */
contract DeploySGHORouter is Script {
    // Mainnet defaults
    address public constant MAINNET_GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address public constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant MAINNET_USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant MAINNET_GSM_USDC = 0xFeeb6FE430B7523fEF2a38327241eE7153779535;
    address public constant MAINNET_GSM_USDT = 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B;

    function run() external returns (SGHORouter helper) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address sgho = vm.envAddress("SGHO");
        address gsmRouter = vm.envAddress("GSM_ROUTER");

        address gho = vm.envOr("GHO", MAINNET_GHO);
        address usdc = vm.envOr("USDC", MAINNET_USDC);
        address usdt = vm.envOr("USDT", MAINNET_USDT);
        address gsmUsdc = vm.envOr("GSM_USDC", MAINNET_GSM_USDC);
        address gsmUsdt = vm.envOr("GSM_USDT", MAINNET_GSM_USDT);

        vm.startBroadcast(deployerPrivateKey);

        helper = new SGHORouter(gsmRouter, sgho, gho, usdc, usdt, gsmUsdc, gsmUsdt);

        vm.stopBroadcast();

        console2.log("SGHORouter deployed at:", address(helper));
    }
}

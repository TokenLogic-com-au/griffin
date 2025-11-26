// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {GSMRouter} from "src/contracts/onboarding/GSMRouter.sol";

/**
 * @title DeployGSMRouter
 * @notice Deployment script for GSMRouter on Ethereum mainnet
 * @dev Run with: forge script script/DeployGSMRouter.s.sol --rpc-url mainnet --broadcast --verify -vv
 */
contract DeployGSMRouter is Script {
    // https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // https://etherscan.io/address/0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    // https://etherscan.io/address/0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E
    address public constant STATA_USDC =
        0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E;

    // https://etherscan.io/address/0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8
    address public constant STATA_USDT =
        0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8;

    // https://etherscan.io/address/0xFeeb6FE430B7523fEF2a38327241eE7153779535
    address internal constant GSM_USDC =
        0xFeeb6FE430B7523fEF2a38327241eE7153779535;

    // https://etherscan.io/address/0x535b2f7C20B9C83d70e519cf9991578eF9816B7B
    address internal constant GSM_USDT =
        0x535b2f7C20B9C83d70e519cf9991578eF9816B7B;

    address internal constant OWNER = address(0);

    function run() external returns (GSMRouter router) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        router = new GSMRouter(OWNER, GHO);

        // Configure token mappings
        router.setTokenConfig(USDC, STATA_USDC, GSM_USDC);
        router.setTokenConfig(USDT, STATA_USDT, GSM_USDT);

        vm.stopBroadcast();
    }
}

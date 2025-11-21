// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GSMRouter} from "../src/GSMRouter.sol";

/**
 * @title Deploy
 * @notice Deployment script for GSMRouter on Ethereum mainnet
 * @dev Run with: forge script script/Deploy.s.sol --rpc-url mainnet --broadcast --verify
 */
contract Deploy is Script {
    // GSM Constants for deployment
    address internal constant GSM_USDC = 0xFeeb6FE430B7523fEF2a38327241eE7153779535;
    address internal constant GSM_USDT = 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B;

    function run() external returns (GSMRouter router) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("\n=== GSMRouter Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy GSMRouter with GSM addresses
        router = new GSMRouter(deployer, GSM_USDC, GSM_USDT);

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("GSMRouter deployed at:", address(router));
        console.log("Owner set to:", deployer);
        console.log("GSM USDC:", router.gsmUSDC());
        console.log("GSM USDT:", router.gsmUSDT());
        console.log("\n");

        return router;
    }
}

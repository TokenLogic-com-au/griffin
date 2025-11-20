// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GHORouter} from "../src/GHORouter.sol";

/**
 * @title Deploy
 * @notice Deployment script for GHORouter on Ethereum mainnet
 * @dev Run with: forge script script/Deploy.s.sol --rpc-url mainnet --broadcast --verify
 */
contract Deploy is Script {
    function run() external returns (GHORouter router) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("\n=== GHORouter Deployment ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy GHORouter
        router = new GHORouter();

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("GHORouter deployed at:", address(router));
        console.log("\n");

        return router;
    }
}

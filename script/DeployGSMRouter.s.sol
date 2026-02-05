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
    // https://etherscan.io/address/0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    function run() external returns (GSMRouter router) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        router = new GSMRouter(owner, GHO);

        vm.stopBroadcast();
    }
}

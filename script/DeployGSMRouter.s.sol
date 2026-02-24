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
    // https://etherscan.io/address/0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6
    address public constant SGHO = 0x73edDFa87C71ADdC275c2b9890f5c3a8480bC9E6;
    // https://etherscan.io/address/0xFeeb6FE430B7523fEF2a38327241eE7153779535
    address public constant GSM_USDC = 0xFeeb6FE430B7523fEF2a38327241eE7153779535;
    // https://etherscan.io/address/0x535b2f7C20B9C83d70e519cf9991578eF9816B7B
    address public constant GSM_USDT = 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        new GSMRouter(owner, GHO, SGHO, GSM_USDC, GSM_USDT);

        vm.stopBroadcast();
    }
}

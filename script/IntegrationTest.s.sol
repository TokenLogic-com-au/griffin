// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GHORouter} from "../src/GHORouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Addresses} from "../src/Addresses.sol";

/**
 * @title IntegrationTest
 * @notice Integration tests for GHORouter on mainnet fork
 * @dev Run with: forge script script/IntegrationTest.s.sol --fork-url $ETH_RPC_URL -vvv
 */
contract IntegrationTest is Script {
    using SafeERC20 for IERC20;

    GHORouter public router;

    // Mainnet whale addresses for testing
    address constant USDC_WHALE = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341; // Wintermute
    address constant USDT_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC; // Binance 8

    address constant USDC = Addresses.USDC;
    address constant USDT = Addresses.USDT;
    address constant GHO = Addresses.GHO;

    function setUp() public {
        router = new GHORouter();

        console.log("\n=== Integration Test Setup ===");
        console.log("Router deployed at:", address(router));
        console.log("USDC:", USDC);
        console.log("USDT:", USDT);
        console.log("GHO:", GHO);
    }

    function run() public {
        setUp();

        console.log("\n=== Running Integration Tests ===\n");

        testAddressesDiscovery();
        testWhaleBalances();
        testSwapReadiness();
        testSwapUSDCToGHO();
        testSwapUSDTToGHO();

        console.log("\n=== Integration Tests Complete ===\n");
    }

    function testAddressesDiscovery() public pure {
        console.log("--- Test: Address Discovery ---");
        console.log("Aave Pool:", Addresses.AAVE_POOL);
        console.log("Staked GHO:", Addresses.STAKED_GHO);
        console.log("GSM USDC:", Addresses.GSM_USDC);
        console.log("GSM USDT:", Addresses.GSM_USDT);
        console.log("stataUSDC:", Addresses.STATA_USDC);
        console.log("stataUSDT:", Addresses.STATA_USDT);
        console.log("[PASS] All addresses configured\n");
    }

    function testWhaleBalances() public view {
        console.log("--- Test: Whale Balances ---");

        uint256 usdcBalance = IERC20(USDC).balanceOf(USDC_WHALE);
        console.log("USDC Whale balance:", usdcBalance / 1e6, "USDC");
        require(usdcBalance > 0, "USDC whale should have balance");

        uint256 usdtBalance = IERC20(USDT).balanceOf(USDT_WHALE);
        console.log("USDT Whale balance:", usdtBalance / 1e6, "USDT");
        require(usdtBalance > 0, "USDT whale should have balance");

        console.log("[PASS] Whale addresses have sufficient balances\n");
    }

    function testSwapReadiness() public view {
        console.log("--- Test: Swap Readiness ---");

        uint256 testAmount = 1000 * 1e6; // 1000 USDC

        uint256 usdcBalance = IERC20(USDC).balanceOf(USDC_WHALE);
        require(usdcBalance >= testAmount, "USDC whale has insufficient balance");
        console.log("[PASS] USDC whale has enough for test swap");

        uint256 usdtBalance = IERC20(USDT).balanceOf(USDT_WHALE);
        require(usdtBalance >= testAmount, "USDT whale has insufficient balance");
        console.log("[PASS] USDT whale has enough for test swap");

        console.log("[PASS] Router ready for swaps\n");

    }

    /**
     * @notice Test USDC to GHO swap
     */
    function testSwapUSDCToGHO() public {
        console.log("--- Test: USDC to GHO Swap ---");

        uint256 usdcAmount = 1000 * 1e6; // 1000 USDC
        address user = USDC_WHALE;

        vm.startPrank(user);

        uint256 initialUsdc = IERC20(USDC).balanceOf(user);
        console.log("Initial USDC balance:", initialUsdc / 1e6);
        require(initialUsdc >= usdcAmount, "Whale should have enough USDC");


        console.log("Swapping 1k USDC");
        IERC20(USDC).approve(address(router), usdcAmount);
        uint256 ghoReceived = router.swapToGHO(USDC, usdcAmount, 0);
        require(ghoReceived > 0, "Should receive GHO");

        // Format GHO amount with decimals (18 decimals)
        console.log("GHO received: %s.%s GHO", ghoReceived / 1e18, (ghoReceived % 1e18) / 1e14);

        vm.stopPrank();
        console.log("[PASS] USDC swap setup validated\n");
    }

    /**
     * @notice Test USDT to GHO swap
     */
    function testSwapUSDTToGHO() public {
        console.log("--- Test: USDT to GHO Swap ---");

        uint256 usdtAmount = 1000 * 1e6; // 1000 USDT
        address user = USDT_WHALE;

        vm.startPrank(user);

        uint256 initialUsdt = IERC20(USDT).balanceOf(user);
        console.log("Initial USDT balance:", initialUsdt / 1e6);
        require(initialUsdt >= usdtAmount, "Whale should have enough USDT");

        IERC20(USDT).forceApprove(address(router), usdtAmount);
        console.log("Swapping 1k USDT");
        uint256 ghoReceived = router.swapToGHO(USDT, usdtAmount, 0);
        require(ghoReceived > 0, "Should receive GHO");

        // Format GHO amount with decimals (18 decimals)
        console.log("GHO received: %s.%s GHO", ghoReceived / 1e18, (ghoReceived % 1e18) / 1e14);

        vm.stopPrank();
        console.log("[PASS] USDT swap setup validated\n");
    }
}

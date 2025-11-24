// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GSMRouter} from "../src/GSMRouter.sol";
import {IGSM} from "../src/interfaces/IGSM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title IntegrationTest
 * @notice Integration tests for GSMRouter on mainnet fork
 * @dev Run with: forge script script/IntegrationTest.s.sol --fork-url $ETH_RPC_URL -vvv
 */
contract IntegrationTest is Script {
    using SafeERC20 for IERC20;

    GSMRouter public router;

    // Mainnet whale addresses for testing
    address constant USDC_WHALE = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341; // Wintermute
    address constant USDT_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC; // Binance 8
    address constant GHO_WHALE = 0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c; // Aave Safety Module

    // Addresses needed for test setup
    address constant GSM_USDC = 0xFeeb6FE430B7523fEF2a38327241eE7153779535;
    address constant GSM_USDT = 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B;

    function setUp() public {
        // Automatically fork if running as a test without CLI fork
        string memory rpcUrl = vm.envOr("ETH_RPC_URL", string(""));
        if (bytes(rpcUrl).length > 0) {
            vm.createSelectFork(rpcUrl);
        }

        router = new GSMRouter(msg.sender, GSM_USDC, GSM_USDT);

        console.log("\n=== Integration Test Setup ===");
        console.log("Router deployed at:", address(router));
        console.log("USDC:", router.USDC());
        console.log("USDT:", router.USDT());
        console.log("GHO:", router.GHO());
    }

    function run() public {
        setUp();

        console.log("\n=== Running Integration Tests ===\n");

        testWhaleBalances();
        testSwapReadiness();
        testSwapUSDCToGHO();
        testSwapUSDTToGHO();
        testSwapGHOToUSDC();
        testSwapGHOToUSDT();

        console.log("\n=== Integration Tests Complete ===\n");
    }

    function testWhaleBalances() public view {
        uint256 usdcBalance = IERC20(router.USDC()).balanceOf(USDC_WHALE);
        require(usdcBalance > 0, "USDC whale should have balance");

        uint256 usdtBalance = IERC20(router.USDT()).balanceOf(USDT_WHALE);
        require(usdtBalance > 0, "USDT whale should have balance");
    }

    function testSwapReadiness() public view {
        console.log("--- Test: Swap Readiness ---");

        uint256 testAmount = 1000 * 1e6; // 1000 USDC

        uint256 usdcBalance = IERC20(router.USDC()).balanceOf(USDC_WHALE);
        require(usdcBalance >= testAmount, "USDC whale has insufficient balance");
        console.log("[PASS] USDC whale has enough for test swap");

        uint256 usdtBalance = IERC20(router.USDT()).balanceOf(USDT_WHALE);
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
        address usdc = router.USDC();

        vm.startPrank(user);

        uint256 initialUsdc = IERC20(usdc).balanceOf(user);
        console.log("Initial USDC balance:", initialUsdc / 1e6);
        require(initialUsdc >= usdcAmount, "Whale should have enough USDC");

        console.log("Swapping 1k USDC");
        IERC20(usdc).approve(address(router), usdcAmount);
        uint256 ghoReceived = router.swapToGHO(usdc, usdcAmount, 0);
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
        address usdt = router.USDT();

        vm.startPrank(user);

        uint256 initialUsdt = IERC20(usdt).balanceOf(user);
        console.log("Initial USDT balance:", initialUsdt / 1e6);
        require(initialUsdt >= usdtAmount, "Whale should have enough USDT");

        IERC20(usdt).forceApprove(address(router), usdtAmount);
        console.log("Swapping 1k USDT");
        uint256 ghoReceived = router.swapToGHO(usdt, usdtAmount, 0);
        require(ghoReceived > 0, "Should receive GHO");

        // Format GHO amount with decimals (18 decimals)
        console.log("GHO received: %s.%s GHO", ghoReceived / 1e18, (ghoReceived % 1e18) / 1e14);

        vm.stopPrank();
        console.log("[PASS] USDT swap setup validated\n");
    }

    /**
     * @notice Test GHO to USDC swap
     */
    function testSwapGHOToUSDC() public {
        console.log("--- Test: GHO to USDC Swap ---");

        uint256 ghoAmount = 100 * 1e18; // 100 GHO
        address user = GHO_WHALE;
        address gho = router.GHO();
        address usdc = router.USDC();

        vm.startPrank(user);

        // Check balance
        uint256 initialGho = IERC20(gho).balanceOf(user);
        require(initialGho >= ghoAmount, "Whale should have enough GHO");

        IERC20(gho).approve(address(router), ghoAmount);
        console.log("Swapping 100 GHO to USDC");
        uint256 usdcReceived = router.swapFromGHO(usdc, ghoAmount, 0);
        require(usdcReceived > 0, "Should receive USDC");

        console.log("USDC received: %s.%s USDC", usdcReceived / 1e6, (usdcReceived % 1e6));

        vm.stopPrank();
        console.log("[PASS] GHO -> USDC swap validated\n");
    }

    /**
     * @notice Test GHO to USDT swap
     */
    function testSwapGHOToUSDT() public {
        console.log("--- Test: GHO to USDT Swap ---");

        uint256 ghoAmount = 100 * 1e18; // 100 GHO
        address user = GHO_WHALE;
        address gho = router.GHO();
        address usdt = router.USDT();

        vm.startPrank(user);

        // Check balance
        uint256 initialGho = IERC20(gho).balanceOf(user);
        require(initialGho >= ghoAmount, "Whale should have enough GHO");

        IERC20(gho).approve(address(router), ghoAmount);
        console.log("Swapping 100 GHO to USDT");
        uint256 usdtReceived = router.swapFromGHO(usdt, ghoAmount, 0);
        require(usdtReceived > 0, "Should receive USDT");

        console.log("USDT received: %s.%s USDT", usdtReceived / 1e6, (usdtReceived % 1e6));

        vm.stopPrank();
        console.log("[PASS] GHO -> USDT swap validated\n");
    }
}

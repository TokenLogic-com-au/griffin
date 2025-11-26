// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {GSMRouter} from "src/contracts/onboarding/GSMRouter.sol";

/**
 * @title GSMRouterTest
 * @notice Integration tests for GSMRouter on mainnet fork
 * @dev Run with: forge test --match-path test/fork/onboarding/GSMRouterTest.t.sol -vvv
 */
contract GSMRouterTest is Test {

    GSMRouter public router;

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    // Static aTokens Constants
    address public constant STATA_USDC =
        0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E;
    address public constant STATA_USDT =
        0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8;

    // Addresses needed for test setup
    address constant GSM_USDC = 0xFeeb6FE430B7523fEF2a38327241eE7153779535;
    address constant GSM_USDT = 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B;

    // Whale addresses for fork testing
    address constant USDC_WHALE = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503; // Binance
    address constant USDT_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC; // Binance
    address constant GHO_WHALE = 0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa;  // Aave Collector

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        router = new GSMRouter(address(this), GHO);

        // Configure token mappings
        router.setTokenConfig(USDC, STATA_USDC, GSM_USDC);
        router.setTokenConfig(USDT, STATA_USDT, GSM_USDT);
    }

    function test_constructor() public view {
        assertEq(router.GHO(), GHO);
        assertEq(router.owner(), address(this));

        (address usdcStata, address usdcGsm) = router.tokenConfig(USDC);
        assertEq(usdcStata, STATA_USDC);
        assertEq(usdcGsm, GSM_USDC);

        (address usdtStata, address usdtGsm) = router.tokenConfig(USDT);
        assertEq(usdtStata, STATA_USDT);
        assertEq(usdtGsm, GSM_USDT);
    }
}

contract SwapToGHOTest is GSMRouterTest {
    function test_swapUSDCToGHO() public {
        uint256 usdcAmount = 1000 * 1e6; // 1000 USDC
        address user = USDC_WHALE;

        vm.startPrank(user);

        assertGe(IERC20(USDC).balanceOf(user), usdcAmount, "Whale should have enough USDC");

        IERC20(USDC).approve(address(router), usdcAmount);
        uint256 ghoReceived = router.swapToGHO(USDC, usdcAmount, 0);

        assertGt(ghoReceived, 0, "Should receive GHO");

        vm.stopPrank();
    }

    function test_swapUSDTToGHO() public {
        uint256 usdtAmount = 1000 * 1e6; // 1000 USDT
        address user = USDT_WHALE;

        vm.startPrank(user);

        assertGe(IERC20(USDT).balanceOf(user), usdtAmount, "Whale should have enough USDT");

        SafeERC20.forceApprove(IERC20(USDT), address(router), usdtAmount);
        uint256 ghoReceived = router.swapToGHO(USDT, usdtAmount, 0);

        assertGt(ghoReceived, 0, "Should receive GHO");

        vm.stopPrank();
    }
}

contract SwapFromGHOTest is GSMRouterTest {
    function test_swapGHOToUSDC() public {
        uint256 ghoAmount = 100 ether;
        address user = GHO_WHALE;

        vm.startPrank(user);

        assertGe(IERC20(GHO).balanceOf(user), ghoAmount, "Whale should have enough GHO");

        IERC20(GHO).approve(address(router), ghoAmount);
        uint256 usdcReceived = router.swapFromGHO(USDC, ghoAmount, 0);

        assertGt(usdcReceived, 0, "Should receive USDC");

        vm.stopPrank();
    }

    function test_swapGHOToUSDT() public {
        uint256 ghoAmount = 100 ether;
        address user = GHO_WHALE;

        vm.startPrank(user);

        assertGe(IERC20(GHO).balanceOf(user), ghoAmount, "Whale should have enough GHO");

        IERC20(GHO).approve(address(router), ghoAmount);
        uint256 usdtReceived = router.swapFromGHO(USDT, ghoAmount, 0);

        assertGt(usdtReceived, 0, "Should receive USDT");

        vm.stopPrank();
    }
}

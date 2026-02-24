// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {GSMRouter} from "src/contracts/onboarding/GSMRouter.sol";
import {IGSMRouter} from "src/interfaces/onboarding/IGSMRouter.sol";
import {IGSM} from "src/interfaces/IGSM.sol";
import {MockSGHO} from "test/mocks/MockSGHO.sol";

/**
 * @title GSMRouterTest
 * @notice Integration tests for GSMRouter on mainnet fork
 * @dev Run with: forge test --match-path test/fork/onboarding/GSMRouterTest.t.sol -vvv
 */
contract GSMRouterTest is Test {
    GSMRouter public router;
    MockSGHO public sgho;

    // https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    // https://etherscan.io/address/0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    // Static aTokens Constants
    // https://etherscan.io/address/0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E
    address public constant STATA_USDC = 0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E;
    // https://etherscan.io/address/0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8
    address public constant STATA_USDT = 0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8;

    // Addresses needed for test setup
    // https://etherscan.io/address/0xFeeb6FE430B7523fEF2a38327241eE7153779535
    address constant GSM_USDC = 0xFeeb6FE430B7523fEF2a38327241eE7153779535;
    // https://etherscan.io/address/0x535b2f7C20B9C83d70e519cf9991578eF9816B7B
    address constant GSM_USDT = 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B;

    // Test user address
    address constant USER = address(0xBEEF);

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        sgho = new MockSGHO(GHO);
        router = new GSMRouter(address(this), GHO, address(sgho), GSM_USDC, GSM_USDT);
    }

    function test_constructor() public view {
        assertEq(router.GHO(), GHO);
        assertEq(router.sGHO(), address(sgho));
        assertEq(router.GSM_USDC(), GSM_USDC);
        assertEq(router.GSM_USDT(), GSM_USDT);
        assertEq(router.owner(), address(this));
    }

    function _primeSwapToGhoCapacity(address token) internal {
        address gsm = token == USDC ? GSM_USDC : GSM_USDT;
        uint256[4] memory ghoAttempts =
            [uint256(5_000 ether), uint256(1_000 ether), uint256(100 ether), uint256(10 ether)];

        for (uint256 i = 0; i < ghoAttempts.length; i++) {
            (, uint256 ghoAmount,,) = IGSM(gsm).getAssetAmountForBuyAsset(ghoAttempts[i]);
            if (ghoAmount == 0) {
                continue;
            }
            deal(GHO, USER, ghoAmount);

            vm.startPrank(USER);
            IERC20(GHO).approve(address(router), ghoAmount);
            router.swapFromGHO(token, ghoAmount, 0);
            vm.stopPrank();
            return;
        }

        revert("failed to prime GSM");
    }
}

contract SwapToGHOTest is GSMRouterTest {
    function test_swap_usdc_to_gho() public {
        uint256 usdcAmount = 1000 * 1e6; // 1000 USDC

        _primeSwapToGhoCapacity(USDC);
        deal(USDC, USER, usdcAmount);

        vm.startPrank(USER);

        IERC20(USDC).approve(address(router), usdcAmount);
        vm.expectEmit(true, true, false, false);
        emit IGSMRouter.SwapToGHO(USER, USDC, 0, 0);
        uint256 ghoReceived = router.swapToGHO(USDC, usdcAmount, 0);

        assertGt(ghoReceived, 0, "Should receive GHO");

        vm.stopPrank();
    }

    function test_swap_usdt_to_gho() public {
        uint256 usdtAmount = 1000 * 1e6; // 1000 USDT

        _primeSwapToGhoCapacity(USDT);
        deal(USDT, USER, usdtAmount);

        vm.startPrank(USER);

        SafeERC20.forceApprove(IERC20(USDT), address(router), usdtAmount);
        vm.expectEmit(true, true, false, false);
        emit IGSMRouter.SwapToGHO(USER, USDT, 0, 0);
        uint256 ghoReceived = router.swapToGHO(USDT, usdtAmount, 0);

        assertGt(ghoReceived, 0, "Should receive GHO");

        vm.stopPrank();
    }

    function test_reverts_swap_to_gho_zero_amount() public {
        vm.startPrank(USER);
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapToGHO(USDC, 0, 0);
        vm.stopPrank();
    }

    function test_reverts_swap_to_gho_slippage_exceeded() public {
        uint256 usdcAmount = 1000 * 1e6; // 1000 USDC

        _primeSwapToGhoCapacity(USDC);
        deal(USDC, USER, usdcAmount);

        vm.startPrank(USER);

        IERC20(USDC).approve(address(router), usdcAmount);

        // Set unreasonably high minGHOAmount to trigger slippage
        vm.expectRevert(IGSMRouter.SlippageExceeded.selector);
        router.swapToGHO(USDC, usdcAmount, type(uint256).max);

        vm.stopPrank();
    }
}

contract SwapFromGHOTest is GSMRouterTest {
    function test_swap_gho_to_usdc() public {
        uint256 ghoAmount = 100 ether;

        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);

        IERC20(GHO).approve(address(router), ghoAmount);
        vm.expectEmit(true, true, false, false);
        emit IGSMRouter.SwapFromGHO(USER, USDC, 0, 0);
        uint256 usdcReceived = router.swapFromGHO(USDC, ghoAmount, 0);

        assertGt(usdcReceived, 0, "Should receive USDC");

        vm.stopPrank();
    }

    function test_swap_gho_to_usdt() public {
        uint256 ghoAmount = 100 ether;

        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);

        IERC20(GHO).approve(address(router), ghoAmount);
        vm.expectEmit(true, true, false, false);
        emit IGSMRouter.SwapFromGHO(USER, USDT, 0, 0);
        uint256 usdtReceived = router.swapFromGHO(USDT, ghoAmount, 0);

        assertGt(usdtReceived, 0, "Should receive USDT");

        vm.stopPrank();
    }

    function test_reverts_swap_from_gho_zero_amount() public {
        vm.startPrank(USER);
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapFromGHO(USDC, 0, 0);
        vm.stopPrank();
    }

    function test_reverts_swap_from_gho_slippage_exceeded() public {
        uint256 ghoAmount = 100 ether;

        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);

        IERC20(GHO).approve(address(router), ghoAmount);

        // Set unreasonably high minOutputAmount to trigger slippage
        vm.expectRevert(IGSMRouter.SlippageExceeded.selector);
        router.swapFromGHO(USDC, ghoAmount, type(uint256).max);

        vm.stopPrank();
    }

    function test_preview_swap_to_gho() public view {
        uint256 usdcAmount = 1000 * 1e6; // 1000 USDC

        (uint256 ghoAmount, uint256 fee) = router.previewSwapToGHO(USDC, usdcAmount);

        assertGt(ghoAmount, 0, "Should preview GHO amount");
        // Fee might be zero depending on GSM config, so we just check it doesn't revert
        assertGe(fee, 0);
    }

    function test_preview_swap_from_gho() public view {
        uint256 ghoAmount = 1000 * 1e18; // 1000 GHO

        (uint256 outputAmount, uint256 fee) = router.previewSwapFromGHO(USDC, ghoAmount);

        assertGt(outputAmount, 0, "Should preview output amount");
        assertGe(fee, 0);
    }
}

contract SwapTosGHOTest is GSMRouterTest {
    function test_swap_usdc_to_sg_ho() public {
        uint256 usdcAmount = 1000 * 1e6;

        _primeSwapToGhoCapacity(USDC);
        deal(USDC, USER, usdcAmount);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(router), usdcAmount);
        vm.expectEmit(true, true, true, false);
        emit IGSMRouter.SwapTosGHO(USER, USDC, address(sgho), 0, 0, 0);
        uint256 shares = router.swapTosGHO(USDC, usdcAmount, 1);
        vm.stopPrank();

        assertGt(shares, 0, "Should receive sGHO shares");
        assertEq(IERC20(address(sgho)).balanceOf(USER), shares, "User should receive minted shares");
    }

    function test_swap_usdt_to_sg_ho() public {
        uint256 usdtAmount = 1000 * 1e6;

        _primeSwapToGhoCapacity(USDT);
        deal(USDT, USER, usdtAmount);

        vm.startPrank(USER);
        SafeERC20.forceApprove(IERC20(USDT), address(router), usdtAmount);
        vm.expectEmit(true, true, true, false);
        emit IGSMRouter.SwapTosGHO(USER, USDT, address(sgho), 0, 0, 0);
        uint256 shares = router.swapTosGHO(USDT, usdtAmount, 1);
        vm.stopPrank();

        assertGt(shares, 0, "Should receive sGHO shares");
        assertEq(IERC20(address(sgho)).balanceOf(USER), shares, "User should receive minted shares");
    }

    function test_swap_gho_to_sg_ho() public {
        uint256 ghoAmount = 100 ether;

        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(router), ghoAmount);
        vm.expectEmit(true, true, true, true);
        emit IGSMRouter.SwapTosGHO(USER, GHO, address(sgho), ghoAmount, ghoAmount, ghoAmount);
        uint256 shares = router.swapTosGHO(GHO, ghoAmount, ghoAmount);
        vm.stopPrank();

        assertEq(shares, ghoAmount, "Mock sGHO should mint 1:1 shares");
        assertEq(IERC20(address(sgho)).balanceOf(USER), ghoAmount, "User should receive all shares");
    }
}

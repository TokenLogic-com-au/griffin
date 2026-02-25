// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {GSMRouter} from "src/contracts/onboarding/GSMRouter.sol";
import {IGSMRouter} from "src/interfaces/onboarding/IGSMRouter.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockGSM} from "test/mocks/MockGSM.sol";
import {MockGSMMaliciousBuy} from "test/mocks/MockGSMMaliciousBuy.sol";
import {MockGSMMaliciousSell} from "test/mocks/MockGSMMaliciousSell.sol";
import {MockGSMWithFees} from "test/mocks/MockGSMWithFees.sol";
import {MockSGHO} from "test/mocks/MockSGHO.sol";
import {MockSGHOWithRate} from "test/mocks/MockSGHOWithRate.sol";
import {MockStaticAToken} from "test/mocks/MockStaticAToken.sol";

contract GSMRouterSwapTosGHOTest is Test {
    using SafeERC20 for IERC20;

    uint256 internal constant INPUT_AMOUNT = 1_000 * 1e6;
    uint256 internal constant GHO_INPUT_AMOUNT = 1_000 * 1e18;
    uint256 internal constant GSM_LIQUIDITY = 10_000_000 * 1e18;
    uint256 internal constant MAX_LIQUIDITY = GSM_LIQUIDITY * 1000;

    address internal USER = makeAddr("user");

    GSMRouter internal router;
    GSMRouter internal routerWithRate;
    GSMRouter internal routerMalicious;
    MockSGHO internal sgho;
    MockSGHOWithRate internal sghoWithRate;
    MockGSMMaliciousSell internal maliciousGsm;
    MockGSMWithFees internal gsmUsdcWithFees;

    address internal USDC;
    address internal USDT;
    address internal GHO;
    address internal STATA_USDC;
    address internal STATA_USDT;
    address internal GSM_USDC;
    address internal GSM_USDT;

    function setUp() public {
        USDC = address(new MockERC20("USDC", "USDC", 6));
        USDT = address(new MockERC20("USDT", "USDT", 6));
        GHO = address(new MockERC20("GHO", "GHO", 18));

        STATA_USDC = address(new MockStaticAToken("stataUSDC", "stataUSDC", 6, USDC));
        STATA_USDT = address(new MockStaticAToken("stataUSDT", "stataUSDT", 6, USDT));

        gsmUsdcWithFees = new MockGSMWithFees(STATA_USDC, GHO, 0);
        GSM_USDC = address(gsmUsdcWithFees);
        GSM_USDT = address(new MockGSM(STATA_USDT, GHO));

        maliciousGsm = new MockGSMMaliciousSell(STATA_USDC, GHO, type(uint256).max / 2);

        // Seed liquidity for all GSM paths and stata redemptions
        MockERC20(GHO).mint(GSM_USDC, GSM_LIQUIDITY);
        MockERC20(GHO).mint(GSM_USDT, GSM_LIQUIDITY);
        MockERC20(GHO).mint(address(maliciousGsm), GSM_LIQUIDITY);

        MockStaticAToken(STATA_USDC).mint(GSM_USDC, MAX_LIQUIDITY);
        MockStaticAToken(STATA_USDT).mint(GSM_USDT, MAX_LIQUIDITY);
        MockStaticAToken(STATA_USDC).mint(address(maliciousGsm), MAX_LIQUIDITY);

        MockERC20(USDC).mint(STATA_USDC, MAX_LIQUIDITY);
        MockERC20(USDT).mint(STATA_USDT, MAX_LIQUIDITY);

        sgho = new MockSGHO(GHO);
        sghoWithRate = new MockSGHOWithRate(GHO);
        router = new GSMRouter(address(this), GHO, address(sgho), GSM_USDC, GSM_USDT);
        routerWithRate = new GSMRouter(address(this), GHO, address(sghoWithRate), GSM_USDC, GSM_USDT);
        routerMalicious = new GSMRouter(address(this), GHO, address(sgho), address(maliciousGsm), GSM_USDT);
    }

    function _mintSgho(address user, uint256 ghoAmount) internal {
        MockERC20(GHO).mint(user, ghoAmount);

        vm.startPrank(user);
        IERC20(GHO).approve(address(sgho), ghoAmount);
        sgho.deposit(ghoAmount, user);
        vm.stopPrank();
    }

    function test_swap_tos_gho_usdc_success() public {
        MockERC20(USDC).mint(USER, INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(router), INPUT_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit IGSMRouter.SwapTosGHO(USER, USDC, address(sgho), INPUT_AMOUNT, INPUT_AMOUNT, INPUT_AMOUNT);

        uint256 shares = router.swapTosGHO(USDC, INPUT_AMOUNT, INPUT_AMOUNT);
        vm.stopPrank();

        assertEq(shares, INPUT_AMOUNT, "shares should be 1:1 with mock path");
        assertEq(IERC20(address(sgho)).balanceOf(USER), INPUT_AMOUNT, "user should receive sGHO");
        assertEq(IERC20(USDC).balanceOf(USER), 0, "user should spend all USDC");
    }

    function test_swap_tos_gho_usdt_success() public {
        MockERC20(USDT).mint(USER, INPUT_AMOUNT);

        vm.startPrank(USER);
        SafeERC20.forceApprove(IERC20(USDT), address(router), INPUT_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IGSMRouter.SwapTosGHO(USER, USDT, address(sgho), INPUT_AMOUNT, INPUT_AMOUNT, INPUT_AMOUNT);

        uint256 shares = router.swapTosGHO(USDT, INPUT_AMOUNT, INPUT_AMOUNT);
        vm.stopPrank();

        assertEq(shares, INPUT_AMOUNT, "shares should be 1:1 with mock path");
        assertEq(IERC20(address(sgho)).balanceOf(USER), INPUT_AMOUNT, "user should receive sGHO");
        assertEq(IERC20(USDT).balanceOf(USER), 0, "user should spend all USDT");
    }

    function test_swap_tos_gho_gho_success() public {
        MockERC20(GHO).mint(USER, GHO_INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(router), GHO_INPUT_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IGSMRouter.SwapTosGHO(USER, GHO, address(sgho), GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT);

        uint256 shares = router.swapTosGHO(GHO, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT);
        vm.stopPrank();

        assertEq(shares, GHO_INPUT_AMOUNT, "shares should match direct GHO deposit");
        assertEq(IERC20(address(sgho)).balanceOf(USER), GHO_INPUT_AMOUNT, "user should receive sGHO");
        assertEq(IERC20(GHO).balanceOf(USER), 0, "user should spend all GHO");
    }

    function test_swap_tos_gho_revert_zero_amount() public {
        vm.prank(USER);
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapTosGHO(USDC, 0, 0);
    }

    function test_swap_tos_gho_revert_invalid_token() public {
        MockERC20(USDC).mint(USER, INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(router), INPUT_AMOUNT);
        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.swapTosGHO(address(0), INPUT_AMOUNT, INPUT_AMOUNT);
        vm.stopPrank();
    }

    function test_swap_tos_gho_revert_unsupported_token() public {
        address unsupportedToken = makeAddr("unsupported-token");
        vm.startPrank(USER);
        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.swapTosGHO(unsupportedToken, INPUT_AMOUNT, INPUT_AMOUNT);
        vm.stopPrank();
    }

    function test_swap_tos_gho_revert_invalid_sgho_asset() public {
        MockSGHO wrongAssetVault = new MockSGHO(USDC);
        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        new GSMRouter(address(this), GHO, address(wrongAssetVault), GSM_USDC, GSM_USDT);
    }

    function test_swap_tos_gho_revert_slippage_exceeded() public {
        sghoWithRate.setExchangeRate(1.1e18);
        MockERC20(GHO).mint(USER, GHO_INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(routerWithRate), GHO_INPUT_AMOUNT);
        vm.expectRevert(IGSMRouter.SlippageExceeded.selector);
        routerWithRate.swapTosGHO(GHO, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT);
        vm.stopPrank();
    }

    function test_swap_tos_gho_usdc_partial_consumption_returns_dust() public {
        gsmUsdcWithFees.setConsumptionBps(9500); // 95% consumed, 5% returned
        MockERC20(USDC).mint(USER, INPUT_AMOUNT);

        uint256 expectedConsumed = (INPUT_AMOUNT * 9500) / 10000;
        uint256 expectedDust = INPUT_AMOUNT - expectedConsumed;

        vm.startPrank(USER);
        IERC20(USDC).approve(address(router), INPUT_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit IGSMRouter.DustReturned(USER, USDC, expectedDust);

        vm.expectEmit(true, true, true, true);
        emit IGSMRouter.SwapTosGHO(USER, USDC, address(sgho), expectedConsumed, expectedConsumed, expectedConsumed);

        uint256 shares = router.swapTosGHO(USDC, INPUT_AMOUNT, expectedConsumed);
        vm.stopPrank();

        assertEq(shares, expectedConsumed, "shares should track consumed amount");
        assertEq(IERC20(USDC).balanceOf(USER), expectedDust, "user should receive USDC dust");
        assertEq(IERC20(address(sgho)).balanceOf(USER), expectedConsumed, "user should receive expected shares");
        assertEq(IERC20(USDC).balanceOf(address(router)), 0, "router should keep no USDC");
        assertEq(IERC20(GHO).balanceOf(address(router)), 0, "router should keep no GHO");
    }

    function test_regression_malicious_gsm_fake_gho_out_uses_balance_delta_only() public {
        uint256 strandedGho = 50 ether;
        MockERC20(GHO).mint(address(routerMalicious), strandedGho);

        MockERC20(USDC).mint(USER, INPUT_AMOUNT * 2);
        vm.startPrank(USER);
        IERC20(USDC).approve(address(routerMalicious), INPUT_AMOUNT * 2);
        vm.expectEmit(true, true, false, true);
        emit IGSMRouter.SwapToGHO(USER, USDC, INPUT_AMOUNT, 0);

        uint256 ghoReceived = routerMalicious.swapToGHO(USDC, INPUT_AMOUNT, 0);

        vm.expectEmit(true, true, true, true);
        emit IGSMRouter.SwapTosGHO(USER, USDC, address(sgho), INPUT_AMOUNT, 0, 0);
        uint256 sghoShares = routerMalicious.swapTosGHO(USDC, INPUT_AMOUNT, 0);

        vm.stopPrank();

        assertEq(ghoReceived, 0, "swapToGHO should use actual GHO delta only");
        assertEq(sghoShares, 0, "swapTosGHO should use actual GHO delta only");
        assertEq(IERC20(GHO).balanceOf(USER), 0, "user should not receive fake GHO");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "user should not receive fake sGHO");
        assertEq(IERC20(GHO).balanceOf(address(routerMalicious)), strandedGho, "router must not spend pre-existing GHO");
    }

    function test_regression_token_to_stata_allowance_cleared_after_swap_to_and_swap_tos() public {
        MockERC20(USDC).mint(USER, INPUT_AMOUNT * 2);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(router), INPUT_AMOUNT * 2);

        vm.expectEmit(true, true, false, true);
        emit IGSMRouter.SwapToGHO(USER, USDC, INPUT_AMOUNT, INPUT_AMOUNT);
        router.swapToGHO(USDC, INPUT_AMOUNT, 0);
        assertEq(
            IERC20(USDC).allowance(address(router), STATA_USDC), 0, "swapToGHO should clear token->stata allowance"
        );

        vm.expectEmit(true, true, true, true);
        emit IGSMRouter.SwapTosGHO(USER, USDC, address(sgho), INPUT_AMOUNT, INPUT_AMOUNT, INPUT_AMOUNT);
        router.swapTosGHO(USDC, INPUT_AMOUNT, 0);
        assertEq(
            IERC20(USDC).allowance(address(router), STATA_USDC), 0, "swapTosGHO should clear token->stata allowance"
        );
        vm.stopPrank();
    }

    function test_swap_froms_gho_gho_success() public {
        _mintSgho(USER, GHO_INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(router), GHO_INPUT_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit IGSMRouter.SwapFromsGHO(USER, address(sgho), GHO, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT);

        uint256 ghoAmount = router.swapFromsGHO(GHO, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT);
        vm.stopPrank();

        assertEq(ghoAmount, GHO_INPUT_AMOUNT, "GHO output should match redeemed shares");
        assertEq(IERC20(GHO).balanceOf(USER), GHO_INPUT_AMOUNT, "user should receive GHO");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "user should spend all sGHO");
    }

    function test_swap_froms_gho_usdc_success() public {
        _mintSgho(USER, GHO_INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(router), GHO_INPUT_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit IGSMRouter.SwapFromsGHO(USER, address(sgho), USDC, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT);

        uint256 outputAmount = router.swapFromsGHO(USDC, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT);
        vm.stopPrank();

        assertEq(outputAmount, GHO_INPUT_AMOUNT, "USDC output should match mock 1:1 route");
        assertEq(IERC20(USDC).balanceOf(USER), GHO_INPUT_AMOUNT, "user should receive USDC");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "user should spend all sGHO");
    }

    function test_swap_froms_gho_revert_zero_amount() public {
        vm.prank(USER);
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapFromsGHO(USDC, 0, 0);
    }

    function test_swap_froms_gho_revert_unsupported_token() public {
        address unsupportedToken = makeAddr("unsupported-token");
        _mintSgho(USER, GHO_INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(router), GHO_INPUT_AMOUNT);
        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.swapFromsGHO(unsupportedToken, GHO_INPUT_AMOUNT, 0);
        vm.stopPrank();
    }

    function test_swap_froms_gho_usdc_partial_consumption_returns_gho_dust() public {
        gsmUsdcWithFees.setConsumptionBps(9500); // 95% consumed, 5% returned
        _mintSgho(USER, GHO_INPUT_AMOUNT);

        uint256 expectedConsumed = (GHO_INPUT_AMOUNT * 9500) / 10000;
        uint256 expectedDust = GHO_INPUT_AMOUNT - expectedConsumed;

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(router), GHO_INPUT_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit IGSMRouter.DustReturned(USER, GHO, expectedDust);

        vm.expectEmit(true, true, true, true);
        emit IGSMRouter.SwapFromsGHO(USER, address(sgho), USDC, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT, expectedConsumed);

        uint256 outputAmount = router.swapFromsGHO(USDC, GHO_INPUT_AMOUNT, expectedConsumed);
        vm.stopPrank();

        assertEq(outputAmount, expectedConsumed, "output should track consumed amount");
        assertEq(IERC20(USDC).balanceOf(USER), expectedConsumed, "user should receive consumed USDC amount");
        assertEq(IERC20(GHO).balanceOf(USER), expectedDust, "user should receive unburned GHO dust");
    }

    function test_swap_froms_gho_revert_slippage_exceeded() public {
        gsmUsdcWithFees.setConsumptionBps(9500);
        _mintSgho(USER, GHO_INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(router), GHO_INPUT_AMOUNT);
        vm.expectRevert(IGSMRouter.SlippageExceeded.selector);
        router.swapFromsGHO(USDC, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT);
        vm.stopPrank();
    }

    function test_preview_swap_tos_gho_quotes_using_vault_rate_and_gsm_fee() public {
        sghoWithRate.setExchangeRate(1.1e18);
        gsmUsdcWithFees.setFeeBps(100); // 1%

        uint256 expectedGho = INPUT_AMOUNT - (INPUT_AMOUNT / 100);
        uint256 expectedShares = (expectedGho * 1e18) / 1.1e18;

        (uint256 usdcShares, uint256 usdcFee) = routerWithRate.previewSwapTosGHO(USDC, INPUT_AMOUNT);
        assertEq(usdcShares, expectedShares, "USDC preview should include GSM fee and vault rate");
        assertEq(usdcFee, INPUT_AMOUNT / 100, "fee should match GSM preview fee");

        (uint256 ghoShares, uint256 ghoFee) = routerWithRate.previewSwapTosGHO(GHO, GHO_INPUT_AMOUNT);
        assertEq(ghoShares, (GHO_INPUT_AMOUNT * 1e18) / 1.1e18, "GHO preview should use vault previewDeposit rate");
        assertEq(ghoFee, 0, "direct GHO->sGHO preview should return zero fee");
    }

    function test_preview_swap_froms_gho_quotes_using_vault_rate_and_gsm_fee() public {
        sghoWithRate.setExchangeRate(1.1e18);
        gsmUsdcWithFees.setFeeBps(100); // 1%

        uint256 shareAmount = GHO_INPUT_AMOUNT;
        uint256 expectedGho = (shareAmount * 11) / 10;
        uint256 expectedFee = expectedGho / 100;
        uint256 expectedOutput = expectedGho - expectedFee;

        (uint256 ghoOutput, uint256 ghoFee) = routerWithRate.previewSwapFromsGHO(GHO, shareAmount);
        assertEq(ghoOutput, expectedGho, "GHO preview should use sGHO previewRedeem rate");
        assertEq(ghoFee, 0, "direct sGHO->GHO preview should return zero fee");

        (uint256 usdcOutput, uint256 usdcFee) = routerWithRate.previewSwapFromsGHO(USDC, shareAmount);
        assertEq(usdcOutput, expectedOutput, "USDC preview should include vault rate and GSM fee");
        assertEq(usdcFee, expectedFee, "fee should match GSM preview fee");
    }

    function test_regression_malicious_gsm_fake_buy_out_uses_balance_delta_only() public {
        MockGSMMaliciousBuy maliciousBuy = new MockGSMMaliciousBuy(STATA_USDC, GHO, INPUT_AMOUNT, GHO_INPUT_AMOUNT);
        GSMRouter routerMaliciousBuy = new GSMRouter(address(this), GHO, address(sgho), address(maliciousBuy), GSM_USDT);

        _mintSgho(USER, GHO_INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(routerMaliciousBuy), GHO_INPUT_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IGSMRouter.SwapFromsGHO(USER, address(sgho), USDC, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT, 0);
        uint256 outputAmount = routerMaliciousBuy.swapFromsGHO(USDC, GHO_INPUT_AMOUNT, 0);
        vm.stopPrank();

        assertEq(outputAmount, 0, "swapFromsGHO should redeem only received stata delta");
        assertEq(IERC20(USDC).balanceOf(USER), 0, "user should not receive fake USDC");
        assertEq(IERC20(GHO).balanceOf(USER), GHO_INPUT_AMOUNT, "all GHO should be returned as dust");
    }

    function test_regression_gho_to_gsm_allowance_cleared_after_swap_froms_gho() public {
        _mintSgho(USER, GHO_INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(router), GHO_INPUT_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IGSMRouter.SwapFromsGHO(USER, address(sgho), USDC, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT);
        router.swapFromsGHO(USDC, GHO_INPUT_AMOUNT, 0);
        vm.stopPrank();

        assertEq(IERC20(GHO).allowance(address(router), GSM_USDC), 0, "swapFromsGHO should clear GHO->GSM allowance");
    }
}

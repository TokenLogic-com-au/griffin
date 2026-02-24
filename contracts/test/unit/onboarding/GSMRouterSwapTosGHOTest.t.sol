// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {GSMRouter} from "src/contracts/onboarding/GSMRouter.sol";
import {IGSMRouter} from "src/interfaces/onboarding/IGSMRouter.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockGSM} from "test/mocks/MockGSM.sol";
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

    function test_swapTosGHO_USDC_success() public {
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

    function test_swapTosGHO_USDT_success() public {
        MockERC20(USDT).mint(USER, INPUT_AMOUNT);

        vm.startPrank(USER);
        SafeERC20.forceApprove(IERC20(USDT), address(router), INPUT_AMOUNT);

        uint256 shares = router.swapTosGHO(USDT, INPUT_AMOUNT, INPUT_AMOUNT);
        vm.stopPrank();

        assertEq(shares, INPUT_AMOUNT, "shares should be 1:1 with mock path");
        assertEq(IERC20(address(sgho)).balanceOf(USER), INPUT_AMOUNT, "user should receive sGHO");
        assertEq(IERC20(USDT).balanceOf(USER), 0, "user should spend all USDT");
    }

    function test_swapTosGHO_GHO_success() public {
        MockERC20(GHO).mint(USER, GHO_INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(router), GHO_INPUT_AMOUNT);

        uint256 shares = router.swapTosGHO(GHO, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT);
        vm.stopPrank();

        assertEq(shares, GHO_INPUT_AMOUNT, "shares should match direct GHO deposit");
        assertEq(IERC20(address(sgho)).balanceOf(USER), GHO_INPUT_AMOUNT, "user should receive sGHO");
        assertEq(IERC20(GHO).balanceOf(USER), 0, "user should spend all GHO");
    }

    function test_swapTosGHO_revert_zeroAmount() public {
        vm.prank(USER);
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapTosGHO(USDC, 0, 0);
    }

    function test_swapTosGHO_revert_invalidToken() public {
        MockERC20(USDC).mint(USER, INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(router), INPUT_AMOUNT);
        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.swapTosGHO(address(0), INPUT_AMOUNT, INPUT_AMOUNT);
        vm.stopPrank();
    }

    function test_swapTosGHO_revert_unsupportedToken() public {
        address unsupportedToken = makeAddr("unsupported-token");
        vm.startPrank(USER);
        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.swapTosGHO(unsupportedToken, INPUT_AMOUNT, INPUT_AMOUNT);
        vm.stopPrank();
    }

    function test_swapTosGHO_revert_invalidSghoAsset() public {
        MockSGHO wrongAssetVault = new MockSGHO(USDC);
        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        new GSMRouter(address(this), GHO, address(wrongAssetVault), GSM_USDC, GSM_USDT);
    }

    function test_swapTosGHO_revert_slippageExceeded() public {
        sghoWithRate.setExchangeRate(1.1e18);
        MockERC20(GHO).mint(USER, GHO_INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(routerWithRate), GHO_INPUT_AMOUNT);
        vm.expectRevert(IGSMRouter.SlippageExceeded.selector);
        routerWithRate.swapTosGHO(GHO, GHO_INPUT_AMOUNT, GHO_INPUT_AMOUNT);
        vm.stopPrank();
    }

    function test_swapTosGHO_USDC_partialConsumption_returnsDust() public {
        gsmUsdcWithFees.setConsumptionBps(9500); // 95% consumed, 5% returned
        MockERC20(USDC).mint(USER, INPUT_AMOUNT);

        uint256 expectedConsumed = (INPUT_AMOUNT * 9500) / 10000;
        uint256 expectedDust = INPUT_AMOUNT - expectedConsumed;

        vm.startPrank(USER);
        IERC20(USDC).approve(address(router), INPUT_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit IGSMRouter.DustReturned(USER, USDC, expectedDust);

        vm.expectEmit(true, true, true, true);
        emit IGSMRouter.SwapTosGHO(
            USER, USDC, address(sgho), expectedConsumed, expectedConsumed, expectedConsumed
        );

        uint256 shares = router.swapTosGHO(USDC, INPUT_AMOUNT, expectedConsumed);
        vm.stopPrank();

        assertEq(shares, expectedConsumed, "shares should track consumed amount");
        assertEq(IERC20(USDC).balanceOf(USER), expectedDust, "user should receive USDC dust");
        assertEq(IERC20(address(sgho)).balanceOf(USER), expectedConsumed, "user should receive expected shares");
        assertEq(IERC20(USDC).balanceOf(address(router)), 0, "router should keep no USDC");
        assertEq(IERC20(GHO).balanceOf(address(router)), 0, "router should keep no GHO");
    }

    function test_regression_maliciousGsm_fakeGhoOut_usesBalanceDeltaOnly() public {
        uint256 strandedGho = 50 ether;
        MockERC20(GHO).mint(address(routerMalicious), strandedGho);

        MockERC20(USDC).mint(USER, INPUT_AMOUNT * 2);
        vm.startPrank(USER);
        IERC20(USDC).approve(address(routerMalicious), INPUT_AMOUNT * 2);

        uint256 ghoReceived = routerMalicious.swapToGHO(USDC, INPUT_AMOUNT, 0);
        uint256 sghoShares = routerMalicious.swapTosGHO(USDC, INPUT_AMOUNT, 0);

        vm.stopPrank();

        assertEq(ghoReceived, 0, "swapToGHO should use actual GHO delta only");
        assertEq(sghoShares, 0, "swapTosGHO should use actual GHO delta only");
        assertEq(IERC20(GHO).balanceOf(USER), 0, "user should not receive fake GHO");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "user should not receive fake sGHO");
        assertEq(IERC20(GHO).balanceOf(address(routerMalicious)), strandedGho, "router must not spend pre-existing GHO");
    }

    function test_regression_tokenToStataAllowance_clearedAfterSwapToAndSwapTos() public {
        MockERC20(USDC).mint(USER, INPUT_AMOUNT * 2);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(router), INPUT_AMOUNT * 2);
        router.swapToGHO(USDC, INPUT_AMOUNT, 0);
        assertEq(
            IERC20(USDC).allowance(address(router), STATA_USDC),
            0,
            "swapToGHO should clear token->stata allowance"
        );

        router.swapTosGHO(USDC, INPUT_AMOUNT, 0);
        assertEq(
            IERC20(USDC).allowance(address(router), STATA_USDC),
            0,
            "swapTosGHO should clear token->stata allowance"
        );
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {GSMRouter} from "src/contracts/onboarding/GSMRouter.sol";
import {sGHORouter} from "src/contracts/onboarding/SGHORouter.sol";
import {ISGHORouter} from "src/interfaces/onboarding/ISGHORouter.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockGSM} from "test/mocks/MockGSM.sol";
import {MockGSMWithFees} from "test/mocks/MockGSMWithFees.sol";
import {MockSGHO} from "test/mocks/MockSGHO.sol";
import {MockSGHOWithRate} from "test/mocks/MockSGHOWithRate.sol";
import {MockStaticAToken} from "test/mocks/MockStaticAToken.sol";

contract SGHORouterFuzzBase is Test {
    using SafeERC20 for IERC20;

    uint256 internal constant GSM_LIQUIDITY = 10_000_000 * 1e18;
    uint256 internal constant MAX_LIQUIDITY = GSM_LIQUIDITY * 1000;

    address internal USER = makeAddr("user");

    GSMRouter internal gsmRouter;
    sGHORouter internal helper;
    MockSGHO internal sgho;

    address internal USDC;
    address internal USDT;
    address internal GHO;
    address internal STATA_USDC;
    address internal STATA_USDT;
    address internal GSM_USDC;
    address internal GSM_USDT;

    function setUp() public virtual {
        USDC = address(new MockERC20("USDC", "USDC", 6));
        USDT = address(new MockERC20("USDT", "USDT", 6));
        GHO = address(new MockERC20("GHO", "GHO", 18));

        STATA_USDC = address(new MockStaticAToken("stataUSDC", "stataUSDC", 6, USDC));
        STATA_USDT = address(new MockStaticAToken("stataUSDT", "stataUSDT", 6, USDT));

        GSM_USDC = address(new MockGSM(STATA_USDC, GHO));
        GSM_USDT = address(new MockGSM(STATA_USDT, GHO));

        MockERC20(GHO).mint(GSM_USDC, GSM_LIQUIDITY);
        MockERC20(GHO).mint(GSM_USDT, GSM_LIQUIDITY);
        MockStaticAToken(STATA_USDC).mint(GSM_USDC, MAX_LIQUIDITY);
        MockStaticAToken(STATA_USDT).mint(GSM_USDT, MAX_LIQUIDITY);
        MockERC20(USDC).mint(STATA_USDC, MAX_LIQUIDITY);
        MockERC20(USDT).mint(STATA_USDT, MAX_LIQUIDITY);

        gsmRouter = new GSMRouter(address(this), GHO);
        sgho = new MockSGHO(GHO);
        helper = new sGHORouter(address(gsmRouter), address(sgho), GHO, USDC, USDT, GSM_USDC, GSM_USDT);
    }

    function _assertNoCustody() internal view {
        assertEq(IERC20(USDC).balanceOf(address(helper)), 0, "helper must not keep USDC");
        assertEq(IERC20(USDT).balanceOf(address(helper)), 0, "helper must not keep USDT");
        assertEq(IERC20(GHO).balanceOf(address(helper)), 0, "helper must not keep GHO");
        assertEq(IERC20(address(sgho)).balanceOf(address(helper)), 0, "helper must not keep sGHO");
    }
}

contract SGHORouterFlowFuzzTest is SGHORouterFuzzBase {
    function test_fuzz_depositUSDC_emitsDeposited(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000 * 1e6);
        MockERC20(USDC).mint(USER, amount);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(helper), amount);

        vm.expectEmit(true, true, false, true, address(helper));
        emit ISGHORouter.Deposited(USER, USDC, amount, amount, amount);

        uint256 shares = helper.deposit(USDC, amount, amount);
        vm.stopPrank();

        assertEq(shares, amount, "shares should match input at 1:1");
        assertEq(IERC20(address(sgho)).balanceOf(USER), amount, "user should receive all shares");
        _assertNoCustody();
    }

    function test_fuzz_roundTripUSDC_noCustody(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000 * 1e6);
        MockERC20(USDC).mint(USER, amount);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(helper), amount);
        uint256 shares = helper.deposit(USDC, amount, amount);

        IERC20(address(sgho)).approve(address(helper), shares);

        vm.expectEmit(true, true, false, true, address(helper));
        emit ISGHORouter.Redeemed(USER, USDC, shares, amount);

        uint256 usdcOut = helper.redeem(shares, USDC, amount);
        vm.stopPrank();

        assertEq(usdcOut, amount, "round-trip should preserve amount at 1:1");
        assertEq(IERC20(USDC).balanceOf(USER), amount, "user should recover USDC");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "all shares should be burned");
        _assertNoCustody();
    }

    function test_fuzz_roundTripUSDT_noCustody(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000 * 1e6);
        MockERC20(USDT).mint(USER, amount);

        vm.startPrank(USER);
        SafeERC20.forceApprove(IERC20(USDT), address(helper), amount);
        uint256 shares = helper.deposit(USDT, amount, amount);
        IERC20(address(sgho)).approve(address(helper), shares);
        uint256 usdtOut = helper.redeem(shares, USDT, amount);
        vm.stopPrank();

        assertEq(usdtOut, amount, "round-trip should preserve amount at 1:1");
        assertEq(IERC20(USDT).balanceOf(USER), amount, "user should recover USDT");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "all shares should be burned");
        _assertNoCustody();
    }

    function test_fuzz_roundTripGHO_noCustody(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000 * 1e18);
        MockERC20(GHO).mint(USER, amount);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(helper), amount);
        uint256 shares = helper.deposit(GHO, amount, amount);
        IERC20(address(sgho)).approve(address(helper), shares);
        uint256 ghoOut = helper.redeem(shares, GHO, amount);
        vm.stopPrank();

        assertEq(shares, amount, "shares should match direct GHO deposit at 1:1");
        assertEq(ghoOut, amount, "round-trip should preserve GHO amount at 1:1");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "all shares should be burned");
        _assertNoCustody();
    }
}

contract SGHORouterDustFuzzTest is Test {
    using SafeERC20 for IERC20;

    uint256 internal constant GSM_LIQUIDITY = 10_000_000 * 1e18;
    uint256 internal constant MAX_LIQUIDITY = GSM_LIQUIDITY * 1000;

    address internal USER = makeAddr("user");

    GSMRouter internal gsmRouter;
    sGHORouter internal helper;
    MockSGHO internal sgho;
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

        MockERC20(GHO).mint(GSM_USDC, GSM_LIQUIDITY);
        MockERC20(GHO).mint(GSM_USDT, GSM_LIQUIDITY);
        MockStaticAToken(STATA_USDC).mint(GSM_USDC, MAX_LIQUIDITY);
        MockStaticAToken(STATA_USDT).mint(GSM_USDT, MAX_LIQUIDITY);
        MockERC20(USDC).mint(STATA_USDC, MAX_LIQUIDITY);
        MockERC20(USDT).mint(STATA_USDT, MAX_LIQUIDITY);

        gsmRouter = new GSMRouter(address(this), GHO);
        sgho = new MockSGHO(GHO);
        helper = new sGHORouter(address(gsmRouter), address(sgho), GHO, USDC, USDT, GSM_USDC, GSM_USDT);
    }

    function test_fuzz_depositUSDC_partialConsumption_forwardsDust(uint256 amount, uint256 consumptionBps) public {
        amount = bound(amount, 1, 1_000_000 * 1e6);
        consumptionBps = bound(consumptionBps, 9000, 9999);
        gsmUsdcWithFees.setConsumptionBps(consumptionBps);

        uint256 expectedConsumed = (amount * consumptionBps) / 10000;
        if (expectedConsumed == 0 && amount > 0) expectedConsumed = 1;
        uint256 expectedDust = amount - expectedConsumed;

        MockERC20(USDC).mint(USER, amount);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(helper), amount);

        if (expectedDust > 0) {
            vm.expectEmit(true, true, false, true, address(helper));
            emit ISGHORouter.DustReturned(USER, USDC, expectedDust);
        }

        vm.expectEmit(true, true, false, true, address(helper));
        emit ISGHORouter.Deposited(USER, USDC, amount, expectedConsumed, expectedConsumed);

        uint256 shares = helper.deposit(USDC, amount, expectedConsumed);
        vm.stopPrank();

        assertEq(shares, expectedConsumed, "shares should equal consumed input");
        assertEq(IERC20(USDC).balanceOf(USER), expectedDust, "USDC dust should be returned");
        assertEq(IERC20(USDC).balanceOf(address(helper)), 0, "helper should keep no USDC");
        assertEq(IERC20(GHO).balanceOf(address(helper)), 0, "helper should keep no GHO");
    }

    function test_fuzz_redeemToUSDC_partialConsumption_forwardsGhoDust(uint256 amount, uint256 consumptionBps) public {
        amount = bound(amount, 1, 1_000_000 * 1e18);
        consumptionBps = bound(consumptionBps, 9000, 9999);
        gsmUsdcWithFees.setConsumptionBps(consumptionBps);

        uint256 expectedUsdcOut = (amount * consumptionBps) / 10000;
        if (expectedUsdcOut == 0 && amount > 0) expectedUsdcOut = 1;
        uint256 expectedGhoDust = amount - expectedUsdcOut;

        MockERC20(GHO).mint(USER, amount);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(helper), amount);
        uint256 shares = helper.deposit(GHO, amount, amount);
        IERC20(address(sgho)).approve(address(helper), shares);

        if (expectedGhoDust > 0) {
            vm.expectEmit(true, true, false, true, address(helper));
            emit ISGHORouter.DustReturned(USER, GHO, expectedGhoDust);
        }

        vm.expectEmit(true, true, false, true, address(helper));
        emit ISGHORouter.Redeemed(USER, USDC, shares, expectedUsdcOut);

        uint256 usdcOut = helper.redeem(shares, USDC, expectedUsdcOut);
        vm.stopPrank();

        assertEq(usdcOut, expectedUsdcOut, "USDC output should match consumed amount");
        assertEq(IERC20(USDC).balanceOf(USER), expectedUsdcOut, "user should receive expected USDC");
        assertEq(IERC20(GHO).balanceOf(USER), expectedGhoDust, "GHO dust should be returned");
        assertEq(IERC20(USDC).balanceOf(address(helper)), 0, "helper should keep no USDC");
        assertEq(IERC20(GHO).balanceOf(address(helper)), 0, "helper should keep no GHO");
    }
}

contract SGHORouterExchangeRateFuzzTest is Test {
    using SafeERC20 for IERC20;

    uint256 internal constant GSM_LIQUIDITY = 10_000_000 * 1e18;
    uint256 internal constant MAX_LIQUIDITY = GSM_LIQUIDITY * 1000;
    uint256 internal constant RATE_PRECISION = 1e18;

    address internal USER = makeAddr("user");

    GSMRouter internal gsmRouter;
    sGHORouter internal helper;
    MockSGHOWithRate internal sgho;

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

        GSM_USDC = address(new MockGSM(STATA_USDC, GHO));
        GSM_USDT = address(new MockGSM(STATA_USDT, GHO));

        MockERC20(GHO).mint(GSM_USDC, GSM_LIQUIDITY);
        MockERC20(GHO).mint(GSM_USDT, GSM_LIQUIDITY);
        MockStaticAToken(STATA_USDC).mint(GSM_USDC, MAX_LIQUIDITY);
        MockStaticAToken(STATA_USDT).mint(GSM_USDT, MAX_LIQUIDITY);
        MockERC20(USDC).mint(STATA_USDC, MAX_LIQUIDITY);
        MockERC20(USDT).mint(STATA_USDT, MAX_LIQUIDITY);

        gsmRouter = new GSMRouter(address(this), GHO);
        sgho = new MockSGHOWithRate(GHO);
        helper = new sGHORouter(address(gsmRouter), address(sgho), GHO, USDC, USDT, GSM_USDC, GSM_USDT);
    }

    function test_fuzz_depositUSDC_variableRate_sharesTrackExchangeRate(uint256 amount, uint256 exchangeRate) public {
        amount = bound(amount, 1, 1_000_000 * 1e6);
        exchangeRate = bound(exchangeRate, 0.5e18, 2e18);
        sgho.setExchangeRate(exchangeRate);

        uint256 expectedShares = (amount * RATE_PRECISION) / exchangeRate;
        MockERC20(USDC).mint(USER, amount);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(helper), amount);
        uint256 shares = helper.deposit(USDC, amount, amount);
        vm.stopPrank();

        assertEq(shares, expectedShares, "shares should follow configured exchange rate");

        if (exchangeRate > RATE_PRECISION) {
            assertLt(shares, amount, "higher exchange rate should mint fewer shares");
        } else if (exchangeRate < RATE_PRECISION) {
            assertGe(shares, amount, "lower exchange rate should mint at least as many shares");
        } else {
            assertEq(shares, amount, "1:1 rate should mint 1:1 shares");
        }
    }

    function test_fuzz_redeemGHO_variableAccrual_assetsTrackRate(uint256 amount, uint256 redeemRate) public {
        amount = bound(amount, 1, 1_000_000 * 1e18);
        redeemRate = bound(redeemRate, 0.5e18, 2e18);

        MockERC20(GHO).mint(USER, amount);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(helper), amount);
        uint256 shares = helper.deposit(GHO, amount, amount);
        vm.stopPrank();

        sgho.setExchangeRate(redeemRate);
        uint256 expectedAssets = (shares * redeemRate) / RATE_PRECISION;

        if (expectedAssets > amount) {
            MockERC20(GHO).mint(address(sgho), expectedAssets - amount);
        }

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(helper), shares);
        uint256 redeemed = helper.redeem(shares, GHO, expectedAssets);
        vm.stopPrank();

        assertEq(redeemed, expectedAssets, "redeemed assets should follow updated rate");
        assertEq(IERC20(GHO).balanceOf(USER), expectedAssets, "user balance should match redeemed assets");
    }
}

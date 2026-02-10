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

contract SGHORouterUnitBase is Test {
    using SafeERC20 for IERC20;

    uint256 internal constant INPUT_AMOUNT = 1_000 * 1e6;
    uint256 internal constant GHO_AMOUNT = 100 * 1e18;
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

        // Seed GSM + stata liquidity for both swap directions.
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

contract SGHORouterConfigUnitTest is SGHORouterUnitBase {
    function test_constructor_setsConfig() public view {
        assertEq(helper.GSM_ROUTER(), address(gsmRouter), "gsm router mismatch");
        assertEq(helper.SGHO(), address(sgho), "sgho mismatch");
        assertEq(helper.GHO(), GHO, "gho mismatch");
        assertEq(helper.USDC(), USDC, "usdc mismatch");
        assertEq(helper.USDT(), USDT, "usdt mismatch");
        assertEq(helper.GSM_USDC(), GSM_USDC, "gsm usdc mismatch");
        assertEq(helper.GSM_USDT(), GSM_USDT, "gsm usdt mismatch");
    }
}

contract DepositUSDCUnitTest is SGHORouterUnitBase {
    function test_deposit_USDC_returnsSharesDirectly() public {
        MockERC20(USDC).mint(USER, INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(helper), INPUT_AMOUNT);

        vm.expectEmit(true, true, false, true, address(helper));
        emit ISGHORouter.Deposited(USER, USDC, INPUT_AMOUNT, INPUT_AMOUNT, INPUT_AMOUNT);

        uint256 shares = helper.deposit(USDC, INPUT_AMOUNT);
        vm.stopPrank();

        assertEq(shares, INPUT_AMOUNT, "shares should match input with 1:1 mocks");
        assertEq(IERC20(address(sgho)).balanceOf(USER), shares, "user should receive shares directly");
        assertEq(IERC20(USDC).balanceOf(USER), 0, "all USDC should be consumed");
        _assertNoCustody();
    }
}

contract DepositUSDTUnitTest is SGHORouterUnitBase {
    function test_deposit_USDT_returnsSharesDirectly() public {
        MockERC20(USDT).mint(USER, INPUT_AMOUNT);

        vm.startPrank(USER);
        SafeERC20.forceApprove(IERC20(USDT), address(helper), INPUT_AMOUNT);
        uint256 shares = helper.deposit(USDT, INPUT_AMOUNT);
        vm.stopPrank();

        assertEq(shares, INPUT_AMOUNT, "shares should match input with 1:1 mocks");
        assertEq(IERC20(address(sgho)).balanceOf(USER), shares, "user should receive shares directly");
        assertEq(IERC20(USDT).balanceOf(USER), 0, "all USDT should be consumed");
        _assertNoCustody();
    }
}

contract DepositGHOUnitTest is SGHORouterUnitBase {
    function test_deposit_GHO_returnsSharesDirectly() public {
        MockERC20(GHO).mint(USER, GHO_AMOUNT);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(helper), GHO_AMOUNT);
        uint256 shares = helper.deposit(GHO, GHO_AMOUNT);
        vm.stopPrank();

        assertEq(shares, GHO_AMOUNT, "shares should match deposited GHO with 1:1 vault");
        assertEq(IERC20(address(sgho)).balanceOf(USER), shares, "user should receive shares directly");
        assertEq(IERC20(GHO).balanceOf(USER), 0, "all GHO should be consumed");
        _assertNoCustody();
    }
}

contract RedeemToUSDCUnitTest is SGHORouterUnitBase {
    function test_redeem_to_USDC_routesThroughGSMRouter() public {
        MockERC20(GHO).mint(USER, INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(helper), INPUT_AMOUNT);
        uint256 shares = helper.deposit(GHO, INPUT_AMOUNT);

        IERC20(address(sgho)).approve(address(helper), shares);

        vm.expectEmit(true, true, false, true, address(helper));
        emit ISGHORouter.Redeemed(USER, USDC, shares, INPUT_AMOUNT);

        uint256 usdcOut = helper.redeem(shares, USDC);
        vm.stopPrank();

        assertEq(usdcOut, INPUT_AMOUNT, "USDC output should be 1:1 in mocks");
        assertEq(IERC20(USDC).balanceOf(USER), INPUT_AMOUNT, "user should receive USDC");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "all shares should be burned");
        _assertNoCustody();
    }
}

contract RedeemToUSDTUnitTest is SGHORouterUnitBase {
    function test_redeem_to_USDT_routesThroughGSMRouter() public {
        MockERC20(GHO).mint(USER, INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(helper), INPUT_AMOUNT);
        uint256 shares = helper.deposit(GHO, INPUT_AMOUNT);

        IERC20(address(sgho)).approve(address(helper), shares);
        uint256 usdtOut = helper.redeem(shares, USDT);
        vm.stopPrank();

        assertEq(usdtOut, INPUT_AMOUNT, "USDT output should be 1:1 in mocks");
        assertEq(IERC20(USDT).balanceOf(USER), INPUT_AMOUNT, "user should receive USDT");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "all shares should be burned");
        _assertNoCustody();
    }
}

contract RedeemToGHOUnitTest is SGHORouterUnitBase {
    function test_redeem_to_GHO_directlyFromVault() public {
        MockERC20(GHO).mint(USER, GHO_AMOUNT);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(helper), GHO_AMOUNT);
        uint256 shares = helper.deposit(GHO, GHO_AMOUNT);

        IERC20(address(sgho)).approve(address(helper), shares);
        uint256 ghoOut = helper.redeem(shares, GHO);
        vm.stopPrank();

        assertEq(ghoOut, GHO_AMOUNT, "GHO output should match shares with 1:1 vault");
        assertEq(IERC20(GHO).balanceOf(USER), GHO_AMOUNT, "user should receive GHO");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "all shares should be burned");
        _assertNoCustody();
    }
}

contract SGHORouterRevertUnitTest is SGHORouterUnitBase {
    address internal INVALID_TOKEN = makeAddr("invalid-token");

    function test_revert_deposit_zeroAmount() public {
        vm.prank(USER);
        vm.expectRevert(ISGHORouter.InvalidAmount.selector);
        helper.deposit(USDC, 0);
    }

    function test_revert_redeem_zeroShares() public {
        vm.prank(USER);
        vm.expectRevert(ISGHORouter.InvalidAmount.selector);
        helper.redeem(0, USDC);
    }

    function test_revert_deposit_invalidToken() public {
        vm.prank(USER);
        vm.expectRevert(ISGHORouter.InvalidToken.selector);
        helper.deposit(INVALID_TOKEN, INPUT_AMOUNT);
    }

    function test_revert_redeem_invalidToken() public {
        vm.prank(USER);
        vm.expectRevert(ISGHORouter.InvalidToken.selector);
        helper.redeem(INPUT_AMOUNT, INVALID_TOKEN);
    }
}

contract SGHORouterDustUnitTest is Test {
    using SafeERC20 for IERC20;

    uint256 internal constant INPUT_AMOUNT = 1_000 * 1e6;
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

        gsmUsdcWithFees.setConsumptionBps(9500); // Leave 5% dust in both directions.

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

    function test_deposit_USDC_forwardsInputDustBackToUser() public {
        uint256 expectedDust = (INPUT_AMOUNT * 500) / 10000;
        uint256 expectedGhoAmount = INPUT_AMOUNT - expectedDust;
        uint256 expectedShares = INPUT_AMOUNT - expectedDust;

        MockERC20(USDC).mint(USER, INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(helper), INPUT_AMOUNT);

        vm.expectEmit(true, true, false, true, address(helper));
        emit ISGHORouter.DustReturned(USER, USDC, expectedDust);

        vm.expectEmit(true, true, false, true, address(helper));
        emit ISGHORouter.Deposited(USER, USDC, INPUT_AMOUNT, expectedGhoAmount, expectedShares);

        uint256 shares = helper.deposit(USDC, INPUT_AMOUNT);
        vm.stopPrank();

        assertEq(shares, expectedShares, "shares should reflect consumed amount");
        assertEq(IERC20(USDC).balanceOf(USER), expectedDust, "USDC dust must be returned");
        assertEq(IERC20(USDC).balanceOf(address(helper)), 0, "helper should keep no USDC");
    }

    function test_redeem_to_USDC_forwardsGhoDustBackToUser() public {
        uint256 expectedUsdcOut = (INPUT_AMOUNT * 9500) / 10000;
        uint256 expectedGhoDust = INPUT_AMOUNT - expectedUsdcOut;

        MockERC20(GHO).mint(USER, INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(helper), INPUT_AMOUNT);
        uint256 shares = helper.deposit(GHO, INPUT_AMOUNT);

        IERC20(address(sgho)).approve(address(helper), shares);

        vm.expectEmit(true, true, false, true, address(helper));
        emit ISGHORouter.DustReturned(USER, GHO, expectedGhoDust);

        vm.expectEmit(true, true, false, true, address(helper));
        emit ISGHORouter.Redeemed(USER, USDC, shares, expectedUsdcOut);

        uint256 usdcOut = helper.redeem(shares, USDC);
        vm.stopPrank();

        assertEq(usdcOut, expectedUsdcOut, "USDC output should reflect 95% consumption");
        assertEq(IERC20(USDC).balanceOf(USER), expectedUsdcOut, "user should receive consumed USDC output");
        assertEq(IERC20(GHO).balanceOf(USER), expectedGhoDust, "unconsumed GHO dust must be returned");
        assertEq(IERC20(USDC).balanceOf(address(helper)), 0, "helper should keep no USDC");
        assertEq(IERC20(GHO).balanceOf(address(helper)), 0, "helper should keep no GHO");
    }
}

contract SGHORouterExchangeRateUnitTest is Test {
    using SafeERC20 for IERC20;

    uint256 internal constant INPUT_AMOUNT = 1_000 * 1e6;
    uint256 internal constant GHO_AMOUNT = 100 * 1e18;
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

    function test_deposit_USDC_nonOneToOneRate_emitsDeposited() public {
        uint256 exchangeRate = 1.25e18;
        sgho.setExchangeRate(exchangeRate);

        uint256 expectedGhoAmount = INPUT_AMOUNT;
        uint256 expectedShares = (expectedGhoAmount * RATE_PRECISION) / exchangeRate;

        MockERC20(USDC).mint(USER, INPUT_AMOUNT);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(helper), INPUT_AMOUNT);

        vm.expectEmit(true, true, false, true, address(helper));
        emit ISGHORouter.Deposited(USER, USDC, INPUT_AMOUNT, expectedGhoAmount, expectedShares);

        uint256 shares = helper.deposit(USDC, INPUT_AMOUNT);
        vm.stopPrank();

        assertEq(shares, expectedShares, "shares should follow exchange rate");
        assertLt(shares, expectedGhoAmount, "with rate > 1, shares should be less than assets");
        assertEq(IERC20(address(sgho)).balanceOf(USER), expectedShares, "user should receive expected shares");
    }

    function test_redeem_GHO_afterYieldAccrual_sharesNotEqualAssets() public {
        uint256 accruedRate = 1.1e18;

        MockERC20(GHO).mint(USER, GHO_AMOUNT);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(helper), GHO_AMOUNT);
        uint256 shares = helper.deposit(GHO, GHO_AMOUNT);
        vm.stopPrank();

        sgho.setExchangeRate(accruedRate);
        uint256 expectedAssets = (shares * accruedRate) / RATE_PRECISION;
        uint256 accruedYield = expectedAssets - GHO_AMOUNT;

        // Top up vault to emulate accrued yield availability.
        MockERC20(GHO).mint(address(sgho), accruedYield);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(helper), shares);

        vm.expectEmit(true, true, false, true, address(helper));
        emit ISGHORouter.Redeemed(USER, GHO, shares, expectedAssets);

        uint256 redeemedAssets = helper.redeem(shares, GHO);
        vm.stopPrank();

        assertEq(redeemedAssets, expectedAssets, "redeemed assets should follow accrued rate");
        assertGt(redeemedAssets, shares, "after accrual, assets should exceed shares");
        assertEq(IERC20(GHO).balanceOf(USER), expectedAssets, "user should receive accrued GHO");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GSMRouter} from "src/contracts/onboarding/GSMRouter.sol";
import {IGSMRouter} from "src/interfaces/onboarding/IGSMRouter.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockGSMWithFees} from "test/mocks/MockGSMWithFees.sol";
import {MockStaticATokenWithRate} from "test/mocks/MockStaticATokenWithRate.sol";

/**
 * @title GSMRouterAdvancedTest
 * @notice Base contract for advanced GSMRouter tests using fee and rate mocks
 */
contract GSMRouterAdvancedTest is Test {
    GSMRouter public router;

    address public USDC;
    address public GHO;
    address public STATA_USDC;
    address public GSM_USDC;

    MockGSMWithFees internal gsmUsdcWithFees;
    MockStaticATokenWithRate internal stataUsdcWithRate;

    function _setUp(uint256 feeBps, uint256 liquidity) internal {
        USDC = address(new MockERC20("USDC", "USDC", 6));
        GHO = address(new MockERC20("GHO", "GHO", 18));

        stataUsdcWithRate = new MockStaticATokenWithRate("stataUSDC", "stataUSDC", 6, USDC);
        STATA_USDC = address(stataUsdcWithRate);

        gsmUsdcWithFees = new MockGSMWithFees(STATA_USDC, GHO, feeBps);
        GSM_USDC = address(gsmUsdcWithFees);

        MockERC20(GHO).mint(GSM_USDC, liquidity);
        stataUsdcWithRate.mint(GSM_USDC, liquidity);
        MockERC20(USDC).mint(STATA_USDC, liquidity);

        router = new GSMRouter(address(this), GHO);
    }
}

// ============================================
// TEST 1: FEE HANDLING TESTS
// ============================================

contract FeeHandlingTest is GSMRouterAdvancedTest {
    function setUp() public {
        _setUp(50, 100_000_000 * 1e18); // 0.5% fee
    }

    function test_swapToGHO_withFee() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(GSM_USDC, amount, 0);

        uint256 expectedFee = (amount * 50) / 10000;
        uint256 expectedGho = amount - expectedFee;

        assertEq(ghoReceived, expectedGho, "Should receive GHO minus fee");
    }

    function test_swapFromGHO_withFee() public {
        uint256 ghoAmount = 1000 * 1e18; // 1000 GHO

        MockERC20(GHO).mint(address(this), ghoAmount);
        IERC20(GHO).approve(address(router), ghoAmount);

        uint256 usdcReceived = router.swapFromGHO(GSM_USDC, ghoAmount, 0);

        uint256 expectedFee = (ghoAmount * 50) / 10000;
        uint256 expectedUsdc = ghoAmount - expectedFee;

        assertEq(usdcReceived, expectedUsdc, "Should receive USDC minus fee");
    }

    function test_previewSwapToGHO_withFee() public view {
        uint256 amount = 1000 * 1e6;

        (uint256 ghoAmount, uint256 fee) = router.previewSwapToGHO(GSM_USDC, amount);

        assertEq(fee, (amount * 50) / 10000, "Fee should be 0.5%");
        assertEq(ghoAmount, amount - fee, "GHO amount should be input minus fee");
    }

    function test_previewSwapFromGHO_withFee() public view {
        uint256 ghoAmount = 1000 * 1e18;

        (uint256 assetAmount, uint256 fee) = router.previewSwapFromGHO(GSM_USDC, ghoAmount);

        assertEq(fee, (ghoAmount * 50) / 10000, "Fee should be 0.5%");
        assertEq(assetAmount, ghoAmount - fee, "Asset amount should be input minus fee");
    }

    function test_fuzz_swapToGHO_withVariableFees(uint256 amount, uint256 feeBps) public {
        amount = bound(amount, 1e6, 1_000_000 * 1e6);
        feeBps = bound(feeBps, 1, 500); // 0.01% to 5%

        gsmUsdcWithFees.setFeeBps(feeBps);

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(GSM_USDC, amount, 0);

        uint256 expectedFee = (amount * feeBps) / 10000;
        uint256 expectedGho = amount - expectedFee;

        assertEq(ghoReceived, expectedGho, "GHO received should match expected after fee");
    }

    function test_slippageProtection_withFees() public {
        uint256 amount = 1000 * 1e6;
        gsmUsdcWithFees.setFeeBps(100); // 1% fee

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        vm.expectRevert(IGSMRouter.SlippageExceeded.selector);
        router.swapToGHO(GSM_USDC, amount, 995 * 1e6);
    }
}

// ============================================
// TEST 2: ROUNDING TESTS AT EXTREME VALUES
// ============================================

contract RoundingTest is GSMRouterAdvancedTest {
    function setUp() public {
        _setUp(0, type(uint128).max); // No fee
    }

    function test_swapToGHO_minimumAmount() public {
        uint256 amount = 1; // 1 wei of USDC

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(GSM_USDC, amount, 0);

        assertGt(ghoReceived, 0, "Should receive some GHO even for 1 wei");
    }

    function test_swapFromGHO_minimumAmount() public {
        uint256 ghoAmount = 1; // 1 wei of GHO

        MockERC20(GHO).mint(address(this), ghoAmount);
        IERC20(GHO).approve(address(router), ghoAmount);

        uint256 usdcReceived = router.swapFromGHO(GSM_USDC, ghoAmount, 0);

        assertLe(usdcReceived, ghoAmount, "Should not receive more than input");
    }

    function test_rounding_withNonUnityExchangeRate() public {
        stataUsdcWithRate.setExchangeRate(1.05e18);

        uint256 amount = 1000 * 1e6;

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(GSM_USDC, amount, 0);

        uint256 expectedShares = (amount * 1e18) / 1.05e18;
        assertApproxEqRel(ghoReceived, expectedShares, 0.01e18, "Should match expected shares calculation");
    }

    function test_fuzz_rounding_noValueLeak(uint256 amount) public {
        amount = bound(amount, 1, 10_000_000 * 1e6);

        uint256 initialUsdcBalance = MockERC20(USDC).balanceOf(address(this));

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(GSM_USDC, amount, 0);

        IERC20(GHO).approve(address(router), ghoReceived);
        uint256 usdcBack = router.swapFromGHO(GSM_USDC, ghoReceived, 0);

        assertLe(usdcBack, amount, "Should not create value from round-trip");
        assertEq(MockERC20(USDC).balanceOf(address(this)), initialUsdcBalance + usdcBack, "Balance accounting correct");
    }

    function test_extremeExchangeRate_high() public {
        stataUsdcWithRate.setExchangeRate(1.1e18);

        uint256 amount = 1000 * 1e6;

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(GSM_USDC, amount, 0);

        uint256 expectedShares = (amount * 10) / 11;
        assertEq(ghoReceived, expectedShares, "Should correctly handle high exchange rate");
    }

    function test_extremeExchangeRate_low() public {
        stataUsdcWithRate.setExchangeRate(0.95e18);

        uint256 amount = 1000 * 1e6;

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(GSM_USDC, amount, 0);

        uint256 expectedShares = (amount * 100) / 95;
        assertEq(ghoReceived, expectedShares, "Should correctly handle low exchange rate");
    }
}

// ============================================
// TEST 3: INTEREST ACCRUAL SIMULATION
// ============================================

contract InterestAccrualTest is GSMRouterAdvancedTest {
    function setUp() public {
        _setUp(0, 100_000_000 * 1e18);
    }

    function test_previewVsActual_withInterestAccrual() public {
        uint256 amount = 1000 * 1e6;

        (uint256 previewGho,) = router.previewSwapToGHO(GSM_USDC, amount);

        stataUsdcWithRate.setExchangeRate(1.001e18);

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        uint256 actualGho = router.swapToGHO(GSM_USDC, amount, 0);

        assertLt(actualGho, previewGho, "Actual should be less after rate increase");

        uint256 diff = previewGho - actualGho;
        assertApproxEqRel(diff, previewGho / 1000, 0.1e18, "Difference should be ~0.1%");
    }

    function test_interestAccrual_benefitsRedeemer() public {
        uint256 ghoAmount = 1000 * 1e18;

        MockERC20(GHO).mint(address(this), ghoAmount);
        IERC20(GHO).approve(address(router), ghoAmount);

        stataUsdcWithRate.setExchangeRate(1.05e18);

        uint256 usdcReceived = router.swapFromGHO(GSM_USDC, ghoAmount, 0);

        assertGt(usdcReceived, ghoAmount, "Should receive more USDC due to interest");
    }

    function test_fuzz_interestAccrual_simulation(uint256 amount, uint256 rateBps) public {
        amount = bound(amount, 1e6, 10_000_000 * 1e6);
        rateBps = bound(rateBps, 10000, 12000);

        uint256 rate = (rateBps * 1e18) / 10000;
        stataUsdcWithRate.setExchangeRate(rate);

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        (uint256 previewGho,) = router.previewSwapToGHO(GSM_USDC, amount);
        uint256 actualGho = router.swapToGHO(GSM_USDC, amount, 0);

        assertEq(actualGho, previewGho, "Preview should match actual at same rate");
    }

    function test_rateChange_betweenPreviewAndExecution() public {
        uint256 amount = 10_000 * 1e6;

        (uint256 previewGho,) = router.previewSwapToGHO(GSM_USDC, amount);

        stataUsdcWithRate.setExchangeRate(1.02e18);

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        vm.expectRevert(IGSMRouter.SlippageExceeded.selector);
        router.swapToGHO(GSM_USDC, amount, previewGho);

        uint256 minWithBuffer = (previewGho * 97) / 100;
        uint256 actualGho = router.swapToGHO(GSM_USDC, amount, minWithBuffer);

        assertGe(actualGho, minWithBuffer, "Should succeed with buffer");
    }
}

// ============================================
// TEST 4: CONCURRENT USER FUZZ TESTS
// ============================================

contract ConcurrentUserTest is GSMRouterAdvancedTest {
    function setUp() public {
        _setUp(10, type(uint128).max); // 0.1% fee
    }

    function test_fuzz_multipleUsers_swapToGHO(uint256 amount1, uint256 amount2, uint256 amount3) public {
        amount1 = bound(amount1, 1e6, 1_000_000 * 1e6);
        amount2 = bound(amount2, 1e6, 1_000_000 * 1e6);
        amount3 = bound(amount3, 1e6, 1_000_000 * 1e6);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");

        MockERC20(USDC).mint(user1, amount1);
        MockERC20(USDC).mint(user2, amount2);
        MockERC20(USDC).mint(user3, amount3);

        vm.startPrank(user1);
        IERC20(USDC).approve(address(router), amount1);
        uint256 gho1 = router.swapToGHO(GSM_USDC, amount1, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        IERC20(USDC).approve(address(router), amount2);
        uint256 gho2 = router.swapToGHO(GSM_USDC, amount2, 0);
        vm.stopPrank();

        vm.startPrank(user3);
        IERC20(USDC).approve(address(router), amount3);
        uint256 gho3 = router.swapToGHO(GSM_USDC, amount3, 0);
        vm.stopPrank();

        assertEq(MockERC20(GHO).balanceOf(user1), gho1, "User1 should have their GHO");
        assertEq(MockERC20(GHO).balanceOf(user2), gho2, "User2 should have their GHO");
        assertEq(MockERC20(GHO).balanceOf(user3), gho3, "User3 should have their GHO");

        assertEq(MockERC20(USDC).balanceOf(user1), 0, "User1 should have spent all USDC");
        assertEq(MockERC20(USDC).balanceOf(user2), 0, "User2 should have spent all USDC");
        assertEq(MockERC20(USDC).balanceOf(user3), 0, "User3 should have spent all USDC");
    }

    function test_mixedOperations_concurrent() public {
        uint256 toGhoAmount = 10_000 * 1e6;
        uint256 fromGhoAmount = 5_000 * 1e18;

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        MockERC20(USDC).mint(user1, toGhoAmount);
        MockERC20(GHO).mint(user2, fromGhoAmount);

        vm.startPrank(user1);
        IERC20(USDC).approve(address(router), toGhoAmount);
        uint256 gho1 = router.swapToGHO(GSM_USDC, toGhoAmount, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        IERC20(GHO).approve(address(router), fromGhoAmount);
        uint256 usdc2 = router.swapFromGHO(GSM_USDC, fromGhoAmount, 0);
        vm.stopPrank();

        assertEq(MockERC20(GHO).balanceOf(user1), gho1, "User1 should have GHO");
        assertEq(MockERC20(USDC).balanceOf(user2), usdc2, "User2 should have USDC");
        assertEq(MockERC20(USDC).balanceOf(user1), 0, "User1 should have no USDC");
        assertEq(MockERC20(GHO).balanceOf(user2), 0, "User2 should have no GHO");

        assertGt(gho1, 0, "User1 should have received GHO");
        assertGt(usdc2, 0, "User2 should have received USDC");
    }

    function test_fuzz_independentUserSwapsToGHO(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 1e6, 100_000 * 1e6);
        amount2 = bound(amount2, 1e6, 100_000 * 1e6);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        MockERC20(USDC).mint(user1, amount1);
        MockERC20(USDC).mint(user2, amount2);

        vm.startPrank(user1);
        IERC20(USDC).approve(address(router), amount1);
        uint256 gho1 = router.swapToGHO(GSM_USDC, amount1, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        IERC20(USDC).approve(address(router), amount2);
        uint256 gho2 = router.swapToGHO(GSM_USDC, amount2, 0);
        vm.stopPrank();

        assertEq(MockERC20(GHO).balanceOf(user1), gho1, "User1 GHO balance");
        assertEq(MockERC20(GHO).balanceOf(user2), gho2, "User2 GHO balance");
        assertEq(MockERC20(USDC).balanceOf(user1), 0, "User1 spent all USDC");
        assertEq(MockERC20(USDC).balanceOf(user2), 0, "User2 spent all USDC");
    }

    function test_fuzz_stressTest_manyUsers(uint8 numUsers) public {
        numUsers = uint8(bound(numUsers, 5, 50));

        uint256[] memory amounts = new uint256[](numUsers);
        address[] memory users = new address[](numUsers);
        uint256[] memory received = new uint256[](numUsers);

        for (uint256 i = 0; i < numUsers; i++) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            amounts[i] = (i + 1) * 1000 * 1e6;
            MockERC20(USDC).mint(users[i], amounts[i]);
        }

        for (uint256 i = 0; i < numUsers; i++) {
            vm.startPrank(users[i]);
            IERC20(USDC).approve(address(router), amounts[i]);
            received[i] = router.swapToGHO(GSM_USDC, amounts[i], 0);
            vm.stopPrank();
        }

        for (uint256 i = 0; i < numUsers; i++) {
            assertEq(MockERC20(GHO).balanceOf(users[i]), received[i], "Each user should have their GHO");
            assertEq(MockERC20(USDC).balanceOf(users[i]), 0, "Each user should have spent USDC");
        }
    }
}

// ============================================
// TEST 5: INVARIANT TESTS
// ============================================

contract InvariantHandler is Test {
    GSMRouter public router;
    MockGSMWithFees public gsm;
    address public usdc;
    address public gho;
    address public stataUsdc;

    address[] public actors;

    constructor(GSMRouter _router, MockGSMWithFees _gsm, address _usdc, address _gho, address _stataUsdc) {
        router = _router;
        gsm = _gsm;
        usdc = _usdc;
        gho = _gho;
        stataUsdc = _stataUsdc;

        for (uint256 i = 0; i < 5; i++) {
            actors.push(makeAddr(string(abi.encodePacked("actor", i))));
        }
    }

    function swapToGHO(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 1e6, 1_000_000 * 1e6);

        MockERC20(usdc).mint(actor, amount);

        vm.startPrank(actor);
        IERC20(usdc).approve(address(router), amount);

        try router.swapToGHO(address(gsm), amount, 0) {} catch {}

        vm.stopPrank();
    }

    function swapFromGHO(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 1e6, 1_000_000 * 1e18);

        MockERC20(gho).mint(actor, amount);

        vm.startPrank(actor);
        IERC20(gho).approve(address(router), amount);

        try router.swapFromGHO(address(gsm), amount, 0) {} catch {}

        vm.stopPrank();
    }

    function setConsumptionRate(uint256 consumptionBps) external {
        consumptionBps = bound(consumptionBps, 9000, 10000); // 90% to 100%
        gsm.setConsumptionBps(consumptionBps);
    }
}

contract InvariantTest is GSMRouterAdvancedTest {
    InvariantHandler public handler;

    function setUp() public {
        _setUp(0, type(uint128).max);

        handler = new InvariantHandler(router, gsmUsdcWithFees, USDC, GHO, STATA_USDC);

        targetContract(address(handler));
    }

    function invariant_routerHoldsNoTokens() public view {
        assertEq(MockERC20(USDC).balanceOf(address(router)), 0, "Router should hold no USDC");
        assertEq(MockERC20(GHO).balanceOf(address(router)), 0, "Router should hold no GHO");
        assertEq(stataUsdcWithRate.balanceOf(address(router)), 0, "Router should hold no stataUSDC");
    }

    function invariant_noResidualApprovals() public view {
        assertEq(IERC20(USDC).allowance(address(router), STATA_USDC), 0, "No residual USDC approval");
        assertEq(IERC20(GHO).allowance(address(router), GSM_USDC), 0, "No residual GHO approval");
        assertEq(stataUsdcWithRate.allowance(address(router), GSM_USDC), 0, "No residual stataUSDC approval");
    }
}

// ============================================
// TEST 6: PARTIAL CONSUMPTION TESTS
// ============================================

contract PartialConsumptionTest is GSMRouterAdvancedTest {
    function setUp() public {
        _setUp(0, type(uint128).max);
    }

    function test_swapToGHO_withPartialConsumption() public {
        // Set GSM to only consume 95% of input
        gsmUsdcWithFees.setConsumptionBps(9500);

        uint256 amount = 1000 * 1e6;

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        router.swapToGHO(GSM_USDC, amount, 0);

        // Router should have no tokens
        assertEq(MockERC20(USDC).balanceOf(address(router)), 0, "Router should hold no USDC");
        assertEq(MockERC20(GHO).balanceOf(address(router)), 0, "Router should hold no GHO");
        assertEq(stataUsdcWithRate.balanceOf(address(router)), 0, "Router should hold no stataUSDC");

        // User should receive dust back (5% of stataTokens redeemed = 50 USDC)
        uint256 dustReceived = MockERC20(USDC).balanceOf(address(this));
        uint256 expectedDust = (amount * 500) / 10000; // 5% dust
        assertEq(dustReceived, expectedDust, "User should receive 5% dust back");
    }

    function test_swapFromGHO_withPartialConsumption() public {
        // Set GSM to only consume 95% of GHO
        gsmUsdcWithFees.setConsumptionBps(9500);

        uint256 ghoAmount = 1000 * 1e18;

        MockERC20(GHO).mint(address(this), ghoAmount);
        IERC20(GHO).approve(address(router), ghoAmount);

        router.swapFromGHO(GSM_USDC, ghoAmount, 0);

        // Router should have no tokens
        assertEq(MockERC20(USDC).balanceOf(address(router)), 0, "Router should hold no USDC");
        assertEq(MockERC20(GHO).balanceOf(address(router)), 0, "Router should hold no GHO");
        assertEq(stataUsdcWithRate.balanceOf(address(router)), 0, "Router should hold no stataUSDC");

        // User should receive GHO dust back
        uint256 finalGhoBalance = MockERC20(GHO).balanceOf(address(this));
        assertGt(finalGhoBalance, 0, "User should receive GHO dust back");
    }

    function test_noResidualAllowances_afterPartialConsumption() public {
        gsmUsdcWithFees.setConsumptionBps(9500);

        uint256 amount = 1000 * 1e6;

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        router.swapToGHO(GSM_USDC, amount, 0);

        // No residual allowances
        assertEq(IERC20(USDC).allowance(address(router), STATA_USDC), 0, "No residual USDC approval");
        assertEq(stataUsdcWithRate.allowance(address(router), GSM_USDC), 0, "No residual stataUSDC approval");
    }

    function test_fuzz_partialConsumption_noResiduals(uint256 amount, uint256 consumptionBps) public {
        amount = bound(amount, 1e6, 1_000_000 * 1e6);
        consumptionBps = bound(consumptionBps, 9000, 10000); // 90% to 100%

        gsmUsdcWithFees.setConsumptionBps(consumptionBps);

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        router.swapToGHO(GSM_USDC, amount, 0);

        // Router should never hold any tokens
        assertEq(MockERC20(USDC).balanceOf(address(router)), 0, "Router should hold no USDC");
        assertEq(MockERC20(GHO).balanceOf(address(router)), 0, "Router should hold no GHO");
        assertEq(stataUsdcWithRate.balanceOf(address(router)), 0, "Router should hold no stataUSDC");

        // No residual allowances
        assertEq(IERC20(USDC).allowance(address(router), STATA_USDC), 0, "No residual USDC approval");
        assertEq(stataUsdcWithRate.allowance(address(router), GSM_USDC), 0, "No residual stataUSDC approval");
    }

    function test_dustReturnedEvent_emitted() public {
        gsmUsdcWithFees.setConsumptionBps(9500);

        uint256 amount = 1000 * 1e6;

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        vm.expectEmit(true, true, false, false);
        emit IGSMRouter.DustReturned(address(this), USDC, 0); // Amount checked loosely

        router.swapToGHO(GSM_USDC, amount, 0);
    }
}

contract SlippageInvariantTest is GSMRouterAdvancedTest {
    function setUp() public {
        _setUp(50, 100_000_000 * 1e18); // 0.5% fee
    }

    function test_fuzz_outputAlwaysGteMinAmount(uint256 amount, uint256 minAmount) public {
        amount = bound(amount, 1e6, 1_000_000 * 1e6);

        MockERC20(USDC).mint(address(this), amount);
        IERC20(USDC).approve(address(router), amount);

        uint256 expectedFee = (amount * 50) / 10000;
        uint256 expectedOutput = amount - expectedFee;

        if (minAmount > expectedOutput) {
            vm.expectRevert(IGSMRouter.SlippageExceeded.selector);
            router.swapToGHO(GSM_USDC, amount, minAmount);
        } else {
            uint256 output = router.swapToGHO(GSM_USDC, amount, minAmount);
            assertGe(output, minAmount, "Output must be >= minAmount");
        }
    }
}

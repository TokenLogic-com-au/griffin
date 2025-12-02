// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GSMRouter} from "src/contracts/onboarding/GSMRouter.sol";
import {IGSMRouter} from "src/interfaces/onboarding/IGSMRouter.sol";
import {IGSM} from "src/interfaces/IGSM.sol";
import {IStaticAToken} from "src/interfaces/IStaticAToken.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockGSMWithFees} from "test/mocks/MockGSMWithFees.sol";
import {MockStaticATokenWithRate} from "test/mocks/MockStaticATokenWithRate.sol";
import {MockGSMBase} from "test/mocks/MockGSMBase.sol";

// ============================================
// TEST 1: FEE HANDLING TESTS
// ============================================

contract FeeHandlingTest is Test {
    GSMRouter public router;

    MockERC20 public usdc;
    MockERC20 public gho;
    MockStaticATokenWithRate public stataUsdc;
    MockGSMWithFees public gsmUsdc;

    uint256 constant LIQUIDITY = 100_000_000 * 1e18;

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        gho = new MockERC20("GHO", "GHO", 18);
        stataUsdc = new MockStaticATokenWithRate("stataUSDC", "stataUSDC", 6, address(usdc));
        gsmUsdc = new MockGSMWithFees(address(stataUsdc), address(gho), 50); // 0.5% fee

        // Fund pools
        gho.mint(address(gsmUsdc), LIQUIDITY);
        stataUsdc.mint(address(gsmUsdc), LIQUIDITY);
        usdc.mint(address(stataUsdc), LIQUIDITY);

        router = new GSMRouter(address(this), address(gho));
        router.setTokenConfig(address(usdc), address(stataUsdc), address(gsmUsdc));
    }

    function test_swapToGHO_withFee() public {
        uint256 amount = 1000 * 1e6; // 1000 USDC

        usdc.mint(address(this), amount);
        usdc.approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(address(usdc), amount, 0);

        // With 0.5% fee, should receive ~995 GHO equivalent
        uint256 expectedFee = (amount * 50) / 10000;
        uint256 expectedGho = amount - expectedFee;

        assertEq(ghoReceived, expectedGho, "Should receive GHO minus fee");
    }

    function test_swapFromGHO_withFee() public {
        uint256 ghoAmount = 1000 * 1e18; // 1000 GHO

        gho.mint(address(this), ghoAmount);
        gho.approve(address(router), ghoAmount);

        uint256 usdcReceived = router.swapFromGHO(address(usdc), ghoAmount, 0);

        // With 0.5% fee, should receive ~995 USDC equivalent
        uint256 expectedFee = (ghoAmount * 50) / 10000;
        uint256 expectedUsdc = ghoAmount - expectedFee;

        assertEq(usdcReceived, expectedUsdc, "Should receive USDC minus fee");
    }

    function test_previewSwapToGHO_withFee() public view {
        uint256 amount = 1000 * 1e6;

        (uint256 ghoAmount, uint256 fee) = router.previewSwapToGHO(address(usdc), amount);

        assertEq(fee, (amount * 50) / 10000, "Fee should be 0.5%");
        assertEq(ghoAmount, amount - fee, "GHO amount should be input minus fee");
    }

    function test_previewSwapFromGHO_withFee() public view {
        uint256 ghoAmount = 1000 * 1e18;

        (uint256 assetAmount, uint256 fee) = router.previewSwapFromGHO(address(usdc), ghoAmount);

        assertEq(fee, (ghoAmount * 50) / 10000, "Fee should be 0.5%");
        assertEq(assetAmount, ghoAmount - fee, "Asset amount should be input minus fee");
    }

    function test_fuzz_swapToGHO_withVariableFees(uint256 amount, uint256 feeBps) public {
        amount = bound(amount, 1e6, 1_000_000 * 1e6);
        feeBps = bound(feeBps, 1, 500); // 0.01% to 5%

        gsmUsdc.setFeeBps(feeBps);

        usdc.mint(address(this), amount);
        usdc.approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(address(usdc), amount, 0);

        uint256 expectedFee = (amount * feeBps) / 10000;
        uint256 expectedGho = amount - expectedFee;

        assertEq(ghoReceived, expectedGho, "GHO received should match expected after fee");
    }

    function test_slippageProtection_withFees() public {
        uint256 amount = 1000 * 1e6;
        gsmUsdc.setFeeBps(100); // 1% fee

        usdc.mint(address(this), amount);
        usdc.approve(address(router), amount);

        // Expect ~990 GHO, setting min to 995 should fail
        vm.expectRevert(IGSMRouter.SlippageExceeded.selector);
        router.swapToGHO(address(usdc), amount, 995 * 1e6);
    }
}

// ============================================
// TEST 2: ROUNDING TESTS AT EXTREME VALUES
// ============================================

contract RoundingTest is Test {
    GSMRouter public router;

    MockERC20 public usdc;
    MockERC20 public gho;
    MockStaticATokenWithRate public stataUsdc;
    MockGSMWithFees public gsmUsdc;

    uint256 constant LIQUIDITY = type(uint128).max;

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        gho = new MockERC20("GHO", "GHO", 18);
        stataUsdc = new MockStaticATokenWithRate("stataUSDC", "stataUSDC", 6, address(usdc));
        gsmUsdc = new MockGSMWithFees(address(stataUsdc), address(gho), 0); // No fee for rounding tests

        // Fund with maximum liquidity
        gho.mint(address(gsmUsdc), LIQUIDITY);
        stataUsdc.mint(address(gsmUsdc), LIQUIDITY);
        usdc.mint(address(stataUsdc), LIQUIDITY);

        router = new GSMRouter(address(this), address(gho));
        router.setTokenConfig(address(usdc), address(stataUsdc), address(gsmUsdc));
    }

    function test_swapToGHO_minimumAmount() public {
        uint256 amount = 1; // 1 wei of USDC

        usdc.mint(address(this), amount);
        usdc.approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(address(usdc), amount, 0);

        assertGt(ghoReceived, 0, "Should receive some GHO even for 1 wei");
    }

    function test_swapFromGHO_minimumAmount() public {
        uint256 ghoAmount = 1; // 1 wei of GHO

        gho.mint(address(this), ghoAmount);
        gho.approve(address(router), ghoAmount);

        uint256 usdcReceived = router.swapFromGHO(address(usdc), ghoAmount, 0);

        // May be 0 due to rounding, should not revert
        assertLe(usdcReceived, ghoAmount, "Should not receive more than input");
    }

    function test_rounding_withNonUnityExchangeRate() public {
        // Set exchange rate to 1.05 (5% interest accrued)
        stataUsdc.setExchangeRate(1.05e18);

        uint256 amount = 1000 * 1e6;

        usdc.mint(address(this), amount);
        usdc.approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(address(usdc), amount, 0);

        // With 1.05 rate: shares = 1000 * 1e18 / 1.05e18 = ~952.38
        // GSM gives 1:1 on shares, so we get ~952 GHO
        uint256 expectedShares = (amount * 1e18) / 1.05e18;
        assertApproxEqRel(ghoReceived, expectedShares, 0.01e18, "Should match expected shares calculation");
    }

    function test_fuzz_rounding_noValueLeak(uint256 amount) public {
        amount = bound(amount, 1, 10_000_000 * 1e6);

        uint256 initialUsdcBalance = usdc.balanceOf(address(this));

        usdc.mint(address(this), amount);
        usdc.approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(address(usdc), amount, 0);

        gho.approve(address(router), ghoReceived);
        uint256 usdcBack = router.swapFromGHO(address(usdc), ghoReceived, 0);

        // Round-trip should not create value (may lose some to rounding)
        assertLe(usdcBack, amount, "Should not create value from round-trip");
        assertEq(usdc.balanceOf(address(this)), initialUsdcBalance + usdcBack, "Balance accounting correct");
    }

    function test_extremeExchangeRate_high() public {
        // Extreme rate: 1 share = 1.1 assets (10% interest)
        stataUsdc.setExchangeRate(1.1e18);

        uint256 amount = 1000 * 1e6;

        usdc.mint(address(this), amount);
        usdc.approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(address(usdc), amount, 0);

        // shares = assets * 1e18 / rate = 1000e6 * 1e18 / 1.1e18 = 1000e6 * 10 / 11
        uint256 expectedShares = (amount * 10) / 11;
        assertEq(ghoReceived, expectedShares, "Should correctly handle high exchange rate");
    }

    function test_extremeExchangeRate_low() public {
        // Rate: 1 share = 0.95 assets
        stataUsdc.setExchangeRate(0.95e18);

        uint256 amount = 1000 * 1e6;

        usdc.mint(address(this), amount);
        usdc.approve(address(router), amount);

        uint256 ghoReceived = router.swapToGHO(address(usdc), amount, 0);

        // shares = assets * 1e18 / rate = 1000e6 * 1e18 / 0.95e18 = 1000e6 * 100 / 95
        uint256 expectedShares = (amount * 100) / 95;
        assertEq(ghoReceived, expectedShares, "Should correctly handle low exchange rate");
    }
}

// ============================================
// TEST 3: INTEREST ACCRUAL SIMULATION
// ============================================

contract InterestAccrualTest is Test {
    GSMRouter public router;

    MockERC20 public usdc;
    MockERC20 public gho;
    MockStaticATokenWithRate public stataUsdc;
    MockGSMWithFees public gsmUsdc;

    uint256 constant LIQUIDITY = 100_000_000 * 1e18;

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        gho = new MockERC20("GHO", "GHO", 18);
        stataUsdc = new MockStaticATokenWithRate("stataUSDC", "stataUSDC", 6, address(usdc));
        gsmUsdc = new MockGSMWithFees(address(stataUsdc), address(gho), 0);

        gho.mint(address(gsmUsdc), LIQUIDITY);
        stataUsdc.mint(address(gsmUsdc), LIQUIDITY);
        usdc.mint(address(stataUsdc), LIQUIDITY);

        router = new GSMRouter(address(this), address(gho));
        router.setTokenConfig(address(usdc), address(stataUsdc), address(gsmUsdc));
    }

    function test_previewVsActual_withInterestAccrual() public {
        uint256 amount = 1000 * 1e6;

        // Preview at current rate
        (uint256 previewGho,) = router.previewSwapToGHO(address(usdc), amount);

        // Simulate interest accrual (rate increases by 0.1%)
        stataUsdc.setExchangeRate(1.001e18);

        usdc.mint(address(this), amount);
        usdc.approve(address(router), amount);

        uint256 actualGho = router.swapToGHO(address(usdc), amount, 0);

        // Actual should be slightly less due to higher exchange rate
        assertLt(actualGho, previewGho, "Actual should be less after rate increase");

        // Difference should be proportional to rate change (~0.1%)
        uint256 diff = previewGho - actualGho;
        assertApproxEqRel(diff, previewGho / 1000, 0.1e18, "Difference should be ~0.1%");
    }

    function test_interestAccrual_benefitsRedeemer() public {
        uint256 ghoAmount = 1000 * 1e18;

        gho.mint(address(this), ghoAmount);
        gho.approve(address(router), ghoAmount);

        // Simulate interest accrual before swap
        stataUsdc.setExchangeRate(1.05e18); // 5% interest

        uint256 usdcReceived = router.swapFromGHO(address(usdc), ghoAmount, 0);

        // With 1.05 rate: shares received * 1.05 = assets
        // If we get X shares from GSM, we redeem X * 1.05 assets
        assertGt(usdcReceived, ghoAmount, "Should receive more USDC due to interest");
    }

    function test_fuzz_interestAccrual_simulation(uint256 amount, uint256 rateBps) public {
        amount = bound(amount, 1e6, 10_000_000 * 1e6);
        rateBps = bound(rateBps, 10000, 12000); // 100% to 120% (0-20% interest)

        uint256 rate = (rateBps * 1e18) / 10000;
        stataUsdc.setExchangeRate(rate);

        usdc.mint(address(this), amount);
        usdc.approve(address(router), amount);

        (uint256 previewGho,) = router.previewSwapToGHO(address(usdc), amount);
        uint256 actualGho = router.swapToGHO(address(usdc), amount, 0);

        // Preview and actual should match when rate doesn't change between calls
        assertEq(actualGho, previewGho, "Preview should match actual at same rate");
    }

    function test_rateChange_betweenPreviewAndExecution() public {
        uint256 amount = 10_000 * 1e6;

        // User previews
        (uint256 previewGho,) = router.previewSwapToGHO(address(usdc), amount);

        // Rate changes (MEV, time passes, etc.)
        stataUsdc.setExchangeRate(1.02e18); // 2% increase

        usdc.mint(address(this), amount);
        usdc.approve(address(router), amount);

        // If user sets minGHOAmount based on preview, tx may fail
        vm.expectRevert(IGSMRouter.SlippageExceeded.selector);
        router.swapToGHO(address(usdc), amount, previewGho);

        // With buffer, it should succeed
        uint256 minWithBuffer = (previewGho * 97) / 100; // 3% buffer
        uint256 actualGho = router.swapToGHO(address(usdc), amount, minWithBuffer);

        assertGe(actualGho, minWithBuffer, "Should succeed with buffer");
    }
}

// ============================================
// TEST 4: CONCURRENT USER FUZZ TESTS
// ============================================

contract ConcurrentUserTest is Test {
    GSMRouter public router;

    MockERC20 public usdc;
    MockERC20 public gho;
    MockStaticATokenWithRate public stataUsdc;
    MockGSMWithFees public gsmUsdc;

    uint256 constant LIQUIDITY = type(uint128).max;

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        gho = new MockERC20("GHO", "GHO", 18);
        stataUsdc = new MockStaticATokenWithRate("stataUSDC", "stataUSDC", 6, address(usdc));
        gsmUsdc = new MockGSMWithFees(address(stataUsdc), address(gho), 10); // 0.1% fee

        gho.mint(address(gsmUsdc), LIQUIDITY);
        stataUsdc.mint(address(gsmUsdc), LIQUIDITY);
        usdc.mint(address(stataUsdc), LIQUIDITY);

        router = new GSMRouter(address(this), address(gho));
        router.setTokenConfig(address(usdc), address(stataUsdc), address(gsmUsdc));
    }

    function test_fuzz_multipleUsers_swapToGHO(uint256 amount1, uint256 amount2, uint256 amount3) public {
        amount1 = bound(amount1, 1e6, 1_000_000 * 1e6);
        amount2 = bound(amount2, 1e6, 1_000_000 * 1e6);
        amount3 = bound(amount3, 1e6, 1_000_000 * 1e6);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");

        // Setup users
        usdc.mint(user1, amount1);
        usdc.mint(user2, amount2);
        usdc.mint(user3, amount3);

        // User 1 swaps
        vm.startPrank(user1);
        usdc.approve(address(router), amount1);
        uint256 gho1 = router.swapToGHO(address(usdc), amount1, 0);
        vm.stopPrank();

        // User 2 swaps
        vm.startPrank(user2);
        usdc.approve(address(router), amount2);
        uint256 gho2 = router.swapToGHO(address(usdc), amount2, 0);
        vm.stopPrank();

        // User 3 swaps
        vm.startPrank(user3);
        usdc.approve(address(router), amount3);
        uint256 gho3 = router.swapToGHO(address(usdc), amount3, 0);
        vm.stopPrank();

        // Verify each user got their GHO
        assertEq(gho.balanceOf(user1), gho1, "User1 should have their GHO");
        assertEq(gho.balanceOf(user2), gho2, "User2 should have their GHO");
        assertEq(gho.balanceOf(user3), gho3, "User3 should have their GHO");

        // Verify no cross-contamination
        assertEq(usdc.balanceOf(user1), 0, "User1 should have spent all USDC");
        assertEq(usdc.balanceOf(user2), 0, "User2 should have spent all USDC");
        assertEq(usdc.balanceOf(user3), 0, "User3 should have spent all USDC");
    }

    function test_mixedOperations_concurrent() public {
        // Test concurrent operations from different users
        uint256 toGhoAmount = 10_000 * 1e6; // 10k USDC
        uint256 fromGhoAmount = 5_000 * 1e18; // 5k GHO

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        usdc.mint(user1, toGhoAmount);
        gho.mint(user2, fromGhoAmount);

        // User 1: USDC -> GHO
        vm.startPrank(user1);
        usdc.approve(address(router), toGhoAmount);
        uint256 gho1 = router.swapToGHO(address(usdc), toGhoAmount, 0);
        vm.stopPrank();

        // User 2: GHO -> USDC (simultaneously possible)
        vm.startPrank(user2);
        gho.approve(address(router), fromGhoAmount);
        uint256 usdc2 = router.swapFromGHO(address(usdc), fromGhoAmount, 0);
        vm.stopPrank();

        // Verify results
        assertEq(gho.balanceOf(user1), gho1, "User1 should have GHO");
        assertEq(usdc.balanceOf(user2), usdc2, "User2 should have USDC");
        assertEq(usdc.balanceOf(user1), 0, "User1 should have no USDC");
        assertEq(gho.balanceOf(user2), 0, "User2 should have no GHO");

        // Verify no cross-contamination
        assertGt(gho1, 0, "User1 should have received GHO");
        assertGt(usdc2, 0, "User2 should have received USDC");
    }

    function test_fuzz_independentUserSwapsToGHO(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 1e6, 100_000 * 1e6);
        amount2 = bound(amount2, 1e6, 100_000 * 1e6);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        usdc.mint(user1, amount1);
        usdc.mint(user2, amount2);

        // Both users swap USDC -> GHO independently
        vm.startPrank(user1);
        usdc.approve(address(router), amount1);
        uint256 gho1 = router.swapToGHO(address(usdc), amount1, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(router), amount2);
        uint256 gho2 = router.swapToGHO(address(usdc), amount2, 0);
        vm.stopPrank();

        // Each user got their own GHO
        assertEq(gho.balanceOf(user1), gho1, "User1 GHO balance");
        assertEq(gho.balanceOf(user2), gho2, "User2 GHO balance");
        assertEq(usdc.balanceOf(user1), 0, "User1 spent all USDC");
        assertEq(usdc.balanceOf(user2), 0, "User2 spent all USDC");
    }

    function test_fuzz_stressTest_manyUsers(uint8 numUsers) public {
        numUsers = uint8(bound(numUsers, 5, 50));

        uint256[] memory amounts = new uint256[](numUsers);
        address[] memory users = new address[](numUsers);
        uint256[] memory received = new uint256[](numUsers);

        // Setup all users
        for (uint256 i = 0; i < numUsers; i++) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            amounts[i] = (i + 1) * 1000 * 1e6; // 1000, 2000, 3000... USDC
            usdc.mint(users[i], amounts[i]);
        }

        // All users swap
        for (uint256 i = 0; i < numUsers; i++) {
            vm.startPrank(users[i]);
            usdc.approve(address(router), amounts[i]);
            received[i] = router.swapToGHO(address(usdc), amounts[i], 0);
            vm.stopPrank();
        }

        // Verify all users got correct amounts
        for (uint256 i = 0; i < numUsers; i++) {
            assertEq(gho.balanceOf(users[i]), received[i], "Each user should have their GHO");
            assertEq(usdc.balanceOf(users[i]), 0, "Each user should have spent USDC");
        }
    }
}

// ============================================
// TEST 5: INVARIANT TESTS
// ============================================

contract InvariantHandler is Test {
    GSMRouter public router;
    MockERC20 public usdc;
    MockERC20 public gho;
    MockStaticATokenWithRate public stataUsdc;

    address[] public actors;

    constructor(GSMRouter _router, MockERC20 _usdc, MockERC20 _gho, MockStaticATokenWithRate _stataUsdc) {
        router = _router;
        usdc = _usdc;
        gho = _gho;
        stataUsdc = _stataUsdc;

        // Create actors
        for (uint256 i = 0; i < 5; i++) {
            actors.push(makeAddr(string(abi.encodePacked("actor", i))));
        }
    }

    function swapToGHO(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 1e6, 1_000_000 * 1e6);

        usdc.mint(actor, amount);

        vm.startPrank(actor);
        usdc.approve(address(router), amount);

        try router.swapToGHO(address(usdc), amount, 0) {} catch {}

        vm.stopPrank();
    }

    function swapFromGHO(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 1e6, 1_000_000 * 1e18);

        gho.mint(actor, amount);

        vm.startPrank(actor);
        gho.approve(address(router), amount);

        try router.swapFromGHO(address(usdc), amount, 0) {} catch {}

        vm.stopPrank();
    }
}

contract InvariantTest is Test {
    GSMRouter public router;
    MockERC20 public usdc;
    MockERC20 public gho;
    MockStaticATokenWithRate public stataUsdc;
    MockGSMWithFees public gsmUsdc;
    InvariantHandler public handler;

    uint256 constant LIQUIDITY = type(uint128).max;

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        gho = new MockERC20("GHO", "GHO", 18);
        stataUsdc = new MockStaticATokenWithRate("stataUSDC", "stataUSDC", 6, address(usdc));
        gsmUsdc = new MockGSMWithFees(address(stataUsdc), address(gho), 0);

        gho.mint(address(gsmUsdc), LIQUIDITY);
        stataUsdc.mint(address(gsmUsdc), LIQUIDITY);
        usdc.mint(address(stataUsdc), LIQUIDITY);

        router = new GSMRouter(address(this), address(gho));
        router.setTokenConfig(address(usdc), address(stataUsdc), address(gsmUsdc));

        handler = new InvariantHandler(router, usdc, gho, stataUsdc);

        targetContract(address(handler));
    }

    /// @notice Router should never hold any token balance after a transaction
    function invariant_routerHoldsNoTokens() public view {
        assertEq(usdc.balanceOf(address(router)), 0, "Router should hold no USDC");
        assertEq(gho.balanceOf(address(router)), 0, "Router should hold no GHO");
        assertEq(stataUsdc.balanceOf(address(router)), 0, "Router should hold no stataUSDC");
    }

    /// @notice Router should have no approvals outstanding (after tx completes)
    function invariant_noResidualApprovals() public view {
        // Note: This tests the current state, approvals happen during tx
        // In production, we'd want to clear approvals after each operation
        assertEq(usdc.allowance(address(router), address(stataUsdc)), 0, "No residual USDC approval");
        assertEq(gho.allowance(address(router), address(gsmUsdc)), 0, "No residual GHO approval");
        assertEq(stataUsdc.allowance(address(router), address(gsmUsdc)), 0, "No residual stataUSDC approval");
    }
}

// Additional invariant test for slippage
contract SlippageInvariantTest is Test {
    GSMRouter public router;
    MockERC20 public usdc;
    MockERC20 public gho;
    MockStaticATokenWithRate public stataUsdc;
    MockGSMWithFees public gsmUsdc;

    uint256 constant LIQUIDITY = 100_000_000 * 1e18;

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        gho = new MockERC20("GHO", "GHO", 18);
        stataUsdc = new MockStaticATokenWithRate("stataUSDC", "stataUSDC", 6, address(usdc));
        gsmUsdc = new MockGSMWithFees(address(stataUsdc), address(gho), 50);

        gho.mint(address(gsmUsdc), LIQUIDITY);
        stataUsdc.mint(address(gsmUsdc), LIQUIDITY);
        usdc.mint(address(stataUsdc), LIQUIDITY);

        router = new GSMRouter(address(this), address(gho));
        router.setTokenConfig(address(usdc), address(stataUsdc), address(gsmUsdc));
    }

    /// @notice User output should always be >= minAmount (or revert)
    function test_fuzz_outputAlwaysGteMinAmount(uint256 amount, uint256 minAmount) public {
        amount = bound(amount, 1e6, 1_000_000 * 1e6);

        usdc.mint(address(this), amount);
        usdc.approve(address(router), amount);

        // Calculate expected output
        uint256 expectedFee = (amount * 50) / 10000;
        uint256 expectedOutput = amount - expectedFee;

        if (minAmount > expectedOutput) {
            // Should revert
            vm.expectRevert(IGSMRouter.SlippageExceeded.selector);
            router.swapToGHO(address(usdc), amount, minAmount);
        } else {
            // Should succeed and output >= minAmount
            uint256 output = router.swapToGHO(address(usdc), amount, minAmount);
            assertGe(output, minAmount, "Output must be >= minAmount");
        }
    }
}

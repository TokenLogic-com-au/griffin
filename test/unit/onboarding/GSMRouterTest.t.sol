// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GSMRouter} from "src/contracts/onboarding/GSMRouter.sol";
import {IGSMRouter} from "src/interfaces/onboarding/IGSMRouter.sol";
import {IGSM} from "src/interfaces/IGSM.sol";
import {IStaticAToken} from "src/interfaces/IStaticAToken.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockGSM} from "test/mocks/MockGSM.sol";
import {MockGSMMaliciousBuy} from "test/mocks/MockGSMMaliciousBuy.sol";
import {MockSGHO} from "test/mocks/MockSGHO.sol";
import {MockStaticAToken} from "test/mocks/MockStaticAToken.sol";

/**
 * @title GSMRouterTest
 * @notice Unit tests for GSMRouter contract
 * @dev Run with: forge test --match-path test/unit/onboarding/GSMRouter.t.sol -vvv
 */
contract GSMRouterTest is Test {
    // Test constants
    uint256 internal constant USDC_AMOUNT = 1000 * 1e6;
    uint256 internal constant GHO_AMOUNT = 1000 * 1e18;
    uint256 internal constant GSM_LIQUIDITY = 10_000_000 * 1e18;
    uint256 internal constant MAX_LIQUIDITY = GSM_LIQUIDITY * 1000; // Ample liquidity for all test scenarios

    GSMRouter public router;

    address public USDC;
    address public USDT;
    address public GHO;
    address public sGHO;

    address public STATA_USDC;
    address public STATA_USDT;

    address internal GSM_USDC;
    address internal GSM_USDT;

    function setUp() public {
        // Deploy Mocks
        USDC = address(new MockERC20("USDC", "USDC", 6));
        USDT = address(new MockERC20("USDT", "USDT", 6));
        GHO = address(new MockERC20("GHO", "GHO", 18));

        STATA_USDC = address(new MockStaticAToken("stataUSDC", "stataUSDC", 6, USDC));
        STATA_USDT = address(new MockStaticAToken("stataUSDT", "stataUSDT", 6, USDT));

        GSM_USDC = address(new MockGSM(STATA_USDC, GHO));
        GSM_USDT = address(new MockGSM(STATA_USDT, GHO));

        // Fund GSMs with liquidity
        MockERC20(GHO).mint(GSM_USDC, GSM_LIQUIDITY);
        MockERC20(GHO).mint(GSM_USDT, GSM_LIQUIDITY);
        MockStaticAToken(STATA_USDC).mint(GSM_USDC, MAX_LIQUIDITY);
        MockStaticAToken(STATA_USDT).mint(GSM_USDT, MAX_LIQUIDITY);

        // Fund StataTokens with underlying liquidity for withdrawals
        MockERC20(USDC).mint(STATA_USDC, MAX_LIQUIDITY);
        MockERC20(USDT).mint(STATA_USDT, MAX_LIQUIDITY);

        sGHO = address(new MockSGHO(GHO));
        router = new GSMRouter(address(this), GHO, sGHO, GSM_USDC, GSM_USDT);
    }

    function _mintAndApprove(address token, uint256 amount) internal {
        _mintAndApprove(token, address(router), amount);
    }

    function _mintAndApprove(address token, address spender, uint256 amount) internal {
        MockERC20(token).mint(address(this), amount);
        IERC20(token).approve(spender, amount);
    }

    function test_constructor() public view {
        assertTrue(address(router) != address(0), "Router should be deployed");
        assertEq(router.owner(), address(this), "Owner should be this contract");

        assertEq(router.GHO(), GHO, "GHO address should match docs");
        assertEq(router.sGHO(), sGHO, "sGHO address should match docs");
        assertEq(router.GSM_USDC(), GSM_USDC, "GSM USDC should match");
        assertEq(router.GSM_USDT(), GSM_USDT, "GSM USDT should match");
    }

    function test_constructor_reverts_zero_gho() public {
        vm.expectRevert(IGSMRouter.ZeroAddress.selector);
        new GSMRouter(address(this), address(0), sGHO, GSM_USDC, GSM_USDT);
    }

    function test_constructor_reverts_zero_sgho() public {
        vm.expectRevert(IGSMRouter.ZeroAddress.selector);
        new GSMRouter(address(this), GHO, address(0), GSM_USDC, GSM_USDT);
    }

    function test_constructor_reverts_invalid_sgho_asset() public {
        address wrongAssetVault = address(new MockSGHO(USDC));

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        new GSMRouter(address(this), GHO, wrongAssetVault, GSM_USDC, GSM_USDT);
    }

    function test_constructor_reverts_duplicate_gsm() public {
        vm.expectRevert(IGSMRouter.InvalidGsm.selector);
        new GSMRouter(address(this), GHO, sGHO, GSM_USDC, GSM_USDC);
    }
}

contract SwapToGHOTest is GSMRouterTest {
    event SwapToGHO(address indexed user, address indexed token, uint256 amount, uint256 ghoAmount);

    function test_swap_to_gho_success() public {
        uint256 expectedGhoAmount = USDC_AMOUNT; // MockGSM returns 1:1

        // Setup: Mint USDC to this contract (acting as user)
        _mintAndApprove(USDC, USDC_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit SwapToGHO(address(this), USDC, USDC_AMOUNT, expectedGhoAmount);

        uint256 received = router.swapToGHO(USDC, USDC_AMOUNT, 0);

        assertEq(received, expectedGhoAmount, "Should return correct GHO amount");
        assertEq(MockERC20(GHO).balanceOf(address(this)), expectedGhoAmount, "User should receive GHO");
        assertEq(MockERC20(USDC).balanceOf(address(this)), 0, "User should spend USDC");
    }

    function test_reverts_zero_amount() public {
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapToGHO(USDC, 0, 0);
    }

    function test_reverts_unsupported_token() public {
        address unsupportedToken = makeAddr("new-token");

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.swapToGHO(unsupportedToken, USDC_AMOUNT, 0);
    }

    function test_constructor_reverts_invalid_gsm_wrong_gho() public {
        address fakeGho = address(new MockERC20("FAKE", "FAKE", 18));
        address wrongGsm = address(new MockGSM(STATA_USDC, fakeGho));

        vm.expectRevert(IGSMRouter.InvalidGsm.selector);
        new GSMRouter(address(this), GHO, sGHO, wrongGsm, GSM_USDT);
    }

    function test_fuzz_swap_to_gho(uint256 amount) public {
        // Bound to reasonable range: 1 wei to 1M tokens (6 decimals)
        amount = bound(amount, 1, 1_000_000 * 1e6);

        _mintAndApprove(USDC, amount);

        uint256 ghoBalanceBefore = MockERC20(GHO).balanceOf(address(this));
        uint256 usdcBalanceBefore = MockERC20(USDC).balanceOf(address(this));

        vm.expectEmit(true, true, false, true);
        emit SwapToGHO(address(this), USDC, amount, amount);

        uint256 received = router.swapToGHO(USDC, amount, 0);

        // MockGSM returns 1:1
        assertEq(received, amount, "Should receive equal GHO amount");
        assertEq(MockERC20(GHO).balanceOf(address(this)), ghoBalanceBefore + amount, "GHO balance should increase");
        assertEq(MockERC20(USDC).balanceOf(address(this)), usdcBalanceBefore - amount, "USDC balance should decrease");
    }

    function test_fuzz_swap_to_gho_with_slippage(uint256 amount, uint256 minGhoAmount) public {
        amount = bound(amount, 1, 1_000_000 * 1e6);
        // minGhoAmount should be <= amount for swap to succeed (MockGSM is 1:1)
        minGhoAmount = bound(minGhoAmount, 0, amount);

        _mintAndApprove(USDC, amount);

        vm.expectEmit(true, true, false, true);
        emit SwapToGHO(address(this), USDC, amount, amount);

        uint256 received = router.swapToGHO(USDC, amount, minGhoAmount);

        assertGe(received, minGhoAmount, "Should receive at least minGhoAmount");
    }
}

contract SwapFromGHOTest is GSMRouterTest {
    event SwapFromGHO(address indexed user, address indexed token, uint256 ghoAmount, uint256 outputAmount);

    function test_swap_from_gho_success() public {
        uint256 expectedUsdcAmount = GHO_AMOUNT; // MockGSM returns 1:1

        // Setup: Mint GHO to this contract (acting as user)
        _mintAndApprove(GHO, GHO_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit SwapFromGHO(address(this), USDC, GHO_AMOUNT, expectedUsdcAmount);

        uint256 received = router.swapFromGHO(USDC, GHO_AMOUNT, 0);

        assertEq(received, expectedUsdcAmount, "Should return correct USDC amount");
        assertEq(MockERC20(USDC).balanceOf(address(this)), expectedUsdcAmount, "User should receive USDC");
        assertEq(MockERC20(GHO).balanceOf(address(this)), 0, "User should spend GHO");
    }

    function test_reverts_unsupported_token() public {
        address unsupportedToken = makeAddr("new-token");

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.swapFromGHO(unsupportedToken, GHO_AMOUNT, 0);
    }

    function test_reverts_zero_amount() public {
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapFromGHO(USDC, 0, 0);
    }

    function test_constructor_reverts_invalid_gsm_wrong_gho() public {
        address fakeGho = address(new MockERC20("FAKE", "FAKE", 18));
        address wrongGsm = address(new MockGSM(STATA_USDC, fakeGho));

        vm.expectRevert(IGSMRouter.InvalidGsm.selector);
        new GSMRouter(address(this), GHO, sGHO, wrongGsm, GSM_USDT);
    }

    function test_fuzz_swap_from_gho(uint256 ghoAmount) public {
        // Bound to reasonable range: 1 wei to 1M GHO (18 decimals)
        ghoAmount = bound(ghoAmount, 1, 1_000_000 * 1e18);

        _mintAndApprove(GHO, ghoAmount);

        uint256 usdcBalanceBefore = MockERC20(USDC).balanceOf(address(this));
        uint256 ghoBalanceBefore = MockERC20(GHO).balanceOf(address(this));

        vm.expectEmit(true, true, false, true);
        emit SwapFromGHO(address(this), USDC, ghoAmount, ghoAmount);

        uint256 received = router.swapFromGHO(USDC, ghoAmount, 0);

        // MockGSM returns 1:1
        assertEq(received, ghoAmount, "Should receive equal USDC amount");
        assertEq(
            MockERC20(USDC).balanceOf(address(this)), usdcBalanceBefore + ghoAmount, "USDC balance should increase"
        );
        assertEq(MockERC20(GHO).balanceOf(address(this)), ghoBalanceBefore - ghoAmount, "GHO balance should decrease");
    }

    function test_fuzz_swap_from_gho_with_slippage(uint256 ghoAmount, uint256 minOutputAmount) public {
        ghoAmount = bound(ghoAmount, 1, 1_000_000 * 1e18);
        // minOutputAmount should be <= ghoAmount for swap to succeed (MockGSM is 1:1)
        minOutputAmount = bound(minOutputAmount, 0, ghoAmount);

        _mintAndApprove(GHO, ghoAmount);

        vm.expectEmit(true, true, false, true);
        emit SwapFromGHO(address(this), USDC, ghoAmount, ghoAmount);

        uint256 received = router.swapFromGHO(USDC, ghoAmount, minOutputAmount);

        assertGe(received, minOutputAmount, "Should receive at least minOutputAmount");
    }

    function test_regression_malicious_buyAsset_return_values_uses_balance_deltas() public {
        MockGSMMaliciousBuy maliciousGsm = new MockGSMMaliciousBuy(STATA_USDC, GHO, 1000 * 1e6, GHO_AMOUNT);
        GSMRouter maliciousRouter = new GSMRouter(address(this), GHO, sGHO, address(maliciousGsm), GSM_USDT);

        uint256 strandedStata = 500 * 1e6;
        MockStaticAToken(STATA_USDC).mint(address(maliciousRouter), strandedStata);

        _mintAndApprove(GHO, address(maliciousRouter), GHO_AMOUNT);

        uint256 usdcBefore = MockERC20(USDC).balanceOf(address(this));
        uint256 ghoBefore = MockERC20(GHO).balanceOf(address(this));

        uint256 received = maliciousRouter.swapFromGHO(USDC, GHO_AMOUNT, 0);

        assertEq(received, 0, "swapFromGHO should redeem only received stata delta");
        assertEq(MockERC20(USDC).balanceOf(address(this)), usdcBefore, "user should not receive drained USDC");
        assertEq(
            MockStaticAToken(STATA_USDC).balanceOf(address(maliciousRouter)),
            strandedStata,
            "router stranded stata should remain untouched"
        );
        assertEq(MockERC20(GHO).balanceOf(address(this)), ghoBefore, "all GHO should be returned as dust");
    }
}

contract PreviewSwapToGHOTest is GSMRouterTest {
    function test_preview_swap_to_gho_success() public view {
        uint256 expectedGhoAmount = USDC_AMOUNT; // MockGSM returns 1:1

        (uint256 ghoAmount, uint256 fee) = router.previewSwapToGHO(USDC, USDC_AMOUNT);

        assertEq(ghoAmount, expectedGhoAmount, "Should preview correct GHO amount");
        assertEq(fee, 0, "Should have 0 fee in mock");
    }

    function test_reverts_unsupported_token() public {
        address unsupportedToken = makeAddr("new-token");

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.previewSwapToGHO(unsupportedToken, USDC_AMOUNT);
    }

    function test_reverts_zero_amount() public {
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.previewSwapToGHO(USDC, 0);
    }

    function test_constructor_reverts_invalid_gsm_wrong_gho() public {
        address fakeGho = address(new MockERC20("FAKE", "FAKE", 18));
        address wrongGsm = address(new MockGSM(STATA_USDC, fakeGho));

        vm.expectRevert(IGSMRouter.InvalidGsm.selector);
        new GSMRouter(address(this), GHO, sGHO, wrongGsm, GSM_USDT);
    }

    function test_fuzz_preview_swap_to_gho(uint256 amount, bool useUSDT) public view {
        amount = bound(amount, 1, 1_000_000 * 1e6);
        address token = useUSDT ? USDT : USDC;

        (uint256 ghoAmount, uint256 fee) = router.previewSwapToGHO(token, amount);

        // MockGSM returns 1:1 with 0 fee
        assertEq(ghoAmount, amount, "Preview should return 1:1 amount");
        assertEq(fee, 0, "Fee should be 0 in mock");
    }
}

contract PreviewSwapFromGHOTest is GSMRouterTest {
    function test_preview_swap_from_gho_success() public view {
        uint256 expectedUsdcAmount = GHO_AMOUNT; // MockGSM returns 1:1

        (uint256 outputAmount, uint256 fee) = router.previewSwapFromGHO(USDC, GHO_AMOUNT);

        assertEq(outputAmount, expectedUsdcAmount, "Should preview correct USDC amount");
        assertEq(fee, 0, "Should have 0 fee in mock");
    }

    function test_reverts_unsupported_token() public {
        address unsupportedToken = makeAddr("new-token");

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.previewSwapFromGHO(unsupportedToken, GHO_AMOUNT);
    }

    function test_reverts_zero_amount() public {
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.previewSwapFromGHO(USDC, 0);
    }

    function test_constructor_reverts_invalid_gsm_wrong_gho() public {
        address fakeGho = address(new MockERC20("FAKE", "FAKE", 18));
        address wrongGsm = address(new MockGSM(STATA_USDC, fakeGho));

        vm.expectRevert(IGSMRouter.InvalidGsm.selector);
        new GSMRouter(address(this), GHO, sGHO, wrongGsm, GSM_USDT);
    }

    function test_fuzz_preview_swap_from_gho(uint256 ghoAmount, bool useUSDT) public view {
        ghoAmount = bound(ghoAmount, 1, 1_000_000 * 1e18);
        address token = useUSDT ? USDT : USDC;

        (uint256 outputAmount, uint256 fee) = router.previewSwapFromGHO(token, ghoAmount);

        // MockGSM returns 1:1 with 0 fee
        assertEq(outputAmount, ghoAmount, "Preview should return 1:1 amount");
        assertEq(fee, 0, "Fee should be 0 in mock");
    }
}

contract PreviewSwapTosGHOTest is GSMRouterTest {
    function test_preview_swap_tos_gho_from_gho_success() public view {
        (uint256 outputAmount, uint256 fee) = router.previewSwapTosGHO(GHO, GHO_AMOUNT);

        assertEq(outputAmount, GHO_AMOUNT, "Should preview correct sGHO amount");
        assertEq(fee, 0, "Direct GHO->sGHO path should have zero GSM fee");
    }

    function test_preview_swap_tos_gho_from_usdc_success() public view {
        (uint256 outputAmount, uint256 fee) = router.previewSwapTosGHO(USDC, USDC_AMOUNT);

        assertEq(outputAmount, USDC_AMOUNT, "Should preview correct sGHO amount");
        assertEq(fee, 0, "Should have 0 fee in mock");
    }

    function test_reverts_preview_swap_tos_gho_unsupported_token() public {
        address unsupportedToken = makeAddr("new-token");

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.previewSwapTosGHO(unsupportedToken, GHO_AMOUNT);
    }

    function test_reverts_preview_swap_tos_gho_zero_amount() public {
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.previewSwapTosGHO(GHO, 0);
    }

    function test_fuzz_preview_swap_tos_gho(uint256 amount, uint8 tokenChoice) public view {
        amount = bound(amount, 1, 1_000_000 * 1e18);

        address token;
        if (tokenChoice % 3 == 0) {
            token = USDC;
        } else if (tokenChoice % 3 == 1) {
            token = USDT;
        } else {
            token = GHO;
        }

        (uint256 outputAmount, uint256 fee) = router.previewSwapTosGHO(token, amount);
        assertEq(outputAmount, amount, "Preview should return 1:1 amount in mock setup");
        if (token == GHO) {
            assertEq(fee, 0, "Direct GHO->sGHO path should have zero fee");
        } else {
            assertEq(fee, 0, "GSM fee should be 0 in mock");
        }
    }
}

contract PreviewSwapFromsGHOTest is GSMRouterTest {
    function test_preview_swap_from_sgho_to_gho_success() public view {
        (uint256 outputAmount, uint256 fee) = router.previewSwapFromsGHO(GHO, GHO_AMOUNT);

        assertEq(outputAmount, GHO_AMOUNT, "Should preview correct GHO output amount");
        assertEq(fee, 0, "Direct sGHO->GHO path should have zero GSM fee");
    }

    function test_preview_swap_from_sgho_to_usdc_success() public view {
        (uint256 outputAmount, uint256 fee) = router.previewSwapFromsGHO(USDC, GHO_AMOUNT);

        assertEq(outputAmount, GHO_AMOUNT, "Should preview correct USDC amount");
        assertEq(fee, 0, "Should have 0 fee in mock");
    }

    function test_reverts_preview_swap_from_sgho_unsupported_token() public {
        address unsupportedToken = makeAddr("new-token");

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.previewSwapFromsGHO(unsupportedToken, GHO_AMOUNT);
    }

    function test_reverts_preview_swap_from_sgho_zero_amount() public {
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.previewSwapFromsGHO(USDC, 0);
    }

    function test_fuzz_preview_swap_from_sgho(uint256 amount, uint8 tokenChoice) public view {
        amount = bound(amount, 1, 1_000_000 * 1e18);

        address token;
        if (tokenChoice % 3 == 0) {
            token = USDC;
        } else if (tokenChoice % 3 == 1) {
            token = USDT;
        } else {
            token = GHO;
        }

        (uint256 outputAmount, uint256 fee) = router.previewSwapFromsGHO(token, amount);
        assertEq(outputAmount, amount, "Preview should return 1:1 amount in mock setup");
        if (token == GHO) {
            assertEq(fee, 0, "Direct sGHO->GHO path should have zero fee");
        } else {
            assertEq(fee, 0, "GSM fee should be 0 in mock");
        }
    }
}

contract RescueTokenTest is GSMRouterTest {
    event Transfer(address indexed from, address indexed to, uint256 value);

    address randomToken = address(new MockERC20("RAND", "RAND", 6));
    uint256 amount = 100 * 1e6;

    function test_rescue_token_success() public {
        // Send tokens to router
        MockERC20(randomToken).mint(address(router), amount);
        assertEq(MockERC20(randomToken).balanceOf(address(router)), amount);

        // Rescue tokens
        address recipient = makeAddr("recipient");

        vm.expectEmit(true, true, false, true, randomToken);
        emit Transfer(address(router), recipient, amount);

        router.rescueToken(randomToken, recipient, amount);

        // Verify
        assertEq(MockERC20(randomToken).balanceOf(address(router)), 0);
        assertEq(MockERC20(randomToken).balanceOf(recipient), amount);
    }

    function test_rescue_token_reverts_not_owner() public {
        address notOwner = makeAddr("notOwner");
        address recipient = makeAddr("recipient");

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        router.rescueToken(randomToken, recipient, amount);
    }
}

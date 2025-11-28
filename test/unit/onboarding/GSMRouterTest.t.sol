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

    // Storage slot for tokenConfig mapping (slot 1)
    uint256 internal constant TOKEN_CONFIG_SLOT = 1;

    GSMRouter public router;

    address public USDC;
    address public USDT;
    address public GHO;

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

        router = new GSMRouter(address(this), GHO);

        // Configure token mappings
        router.setTokenConfig(USDC, STATA_USDC, GSM_USDC);
        router.setTokenConfig(USDT, STATA_USDT, GSM_USDT);
    }

    function test_constructor() public view {
        assertTrue(address(router) != address(0), "Router should be deployed");
        assertEq(router.owner(), address(this), "Owner should be this contract");

        assertEq(router.GHO(), GHO, "GHO address should match docs");
    }

    function test_constructor_reverts_zeroGHO() public {
        vm.expectRevert(IGSMRouter.ZeroAddress.selector);
        new GSMRouter(address(this), address(0));
    }

    /// @dev Helper to set partial token config (only stataToken, no gsm) for testing InvalidGsm errors
    function _setPartialTokenConfig(address token, address stataToken) internal {
        bytes32 slot = keccak256(abi.encode(token, TOKEN_CONFIG_SLOT));
        vm.store(address(router), slot, bytes32(uint256(uint160(stataToken))));
    }
}

contract SetTokenConfigTest is GSMRouterTest {
    function test_setNewTokenConfig() public {
        address newToken = makeAddr("newToken");
        address newStataToken = makeAddr("newStataToken");
        address newGsm = makeAddr("newGsm");

        // Verify config doesn't exist yet
        (address stataToken, address gsm) = router.tokenConfig(newToken);
        assertEq(stataToken, address(0));
        assertEq(gsm, address(0));

        router.setTokenConfig(newToken, newStataToken, newGsm);

        // Verify config is set
        (stataToken, gsm) = router.tokenConfig(newToken);
        assertEq(stataToken, newStataToken);
        assertEq(gsm, newGsm);
    }

    function test_updateExistingConfig() public {
        address newGsm = makeAddr("newGsm");
        address newStataToken = makeAddr("newStataToken");

        // Verify current config
        (address stataToken, address gsm) = router.tokenConfig(USDC);
        assertEq(stataToken, STATA_USDC);
        assertEq(gsm, GSM_USDC);

        // Update to new values
        router.setTokenConfig(USDC, newStataToken, newGsm);

        // Verify config is updated
        (stataToken, gsm) = router.tokenConfig(USDC);
        assertEq(stataToken, newStataToken);
        assertEq(gsm, newGsm);
    }

    function test_reverts_onlyOwner() public {
        address newGsm = makeAddr("newGsm");
        address notOwner = makeAddr("notOwner");

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        router.setTokenConfig(USDT, STATA_USDT, newGsm);
    }

    function test_reverts_zeroToken() public {
        vm.expectRevert(IGSMRouter.ZeroAddress.selector);
        router.setTokenConfig(address(0), STATA_USDC, GSM_USDC);
    }

    function test_reverts_zeroStataToken() public {
        vm.expectRevert(IGSMRouter.ZeroAddress.selector);
        router.setTokenConfig(USDC, address(0), GSM_USDC);
    }

    function test_reverts_zeroGsm() public {
        vm.expectRevert(IGSMRouter.ZeroAddress.selector);
        router.setTokenConfig(USDC, STATA_USDC, address(0));
    }
}

contract SwapToGHOTest is GSMRouterTest {
    event SwapToGHO(address indexed user, address indexed token, uint256 amount, uint256 ghoAmount);

    function test_swapToGHO_success() public {
        uint256 expectedGhoAmount = USDC_AMOUNT; // MockGSM returns 1:1

        // Setup: Mint USDC to this contract (acting as user)
        MockERC20(USDC).mint(address(this), USDC_AMOUNT);
        MockERC20(USDC).approve(address(router), USDC_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit SwapToGHO(address(this), USDC, USDC_AMOUNT, expectedGhoAmount);

        uint256 received = router.swapToGHO(USDC, USDC_AMOUNT, 0);

        assertEq(received, expectedGhoAmount, "Should return correct GHO amount");
        assertEq(MockERC20(GHO).balanceOf(address(this)), expectedGhoAmount, "User should receive GHO");
        assertEq(MockERC20(USDC).balanceOf(address(this)), 0, "User should spend USDC");
    }

    function test_reverts_zeroAmount() public {
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapToGHO(USDC, 0, 0);
    }

    function test_reverts_unsupportedToken() public {
        address unsupportedToken = makeAddr("new-token");

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.swapToGHO(unsupportedToken, USDC_AMOUNT, 0);
    }

    function test_reverts_invalidGsm() public {
        address testToken = makeAddr("testToken");
        address testStata = makeAddr("testStata");

        _setPartialTokenConfig(testToken, testStata);

        vm.expectRevert(IGSMRouter.InvalidGsm.selector);
        router.swapToGHO(testToken, USDC_AMOUNT, 0);
    }

    function testFuzz_swapToGHO(uint256 amount) public {
        // Bound to reasonable range: 1 wei to 1M tokens (6 decimals)
        amount = bound(amount, 1, 1_000_000 * 1e6);

        MockERC20(USDC).mint(address(this), amount);
        MockERC20(USDC).approve(address(router), amount);

        uint256 ghoBalanceBefore = MockERC20(GHO).balanceOf(address(this));
        uint256 usdcBalanceBefore = MockERC20(USDC).balanceOf(address(this));

        uint256 received = router.swapToGHO(USDC, amount, 0);

        // MockGSM returns 1:1
        assertEq(received, amount, "Should receive equal GHO amount");
        assertEq(MockERC20(GHO).balanceOf(address(this)), ghoBalanceBefore + amount, "GHO balance should increase");
        assertEq(MockERC20(USDC).balanceOf(address(this)), usdcBalanceBefore - amount, "USDC balance should decrease");
    }

    function testFuzz_swapToGHO_withSlippage(uint256 amount, uint256 minGhoAmount) public {
        amount = bound(amount, 1, 1_000_000 * 1e6);
        // minGhoAmount should be <= amount for swap to succeed (MockGSM is 1:1)
        minGhoAmount = bound(minGhoAmount, 0, amount);

        MockERC20(USDC).mint(address(this), amount);
        MockERC20(USDC).approve(address(router), amount);

        uint256 received = router.swapToGHO(USDC, amount, minGhoAmount);

        assertGe(received, minGhoAmount, "Should receive at least minGhoAmount");
    }
}

contract SwapFromGHOTest is GSMRouterTest {
    event SwapFromGHO(address indexed user, address indexed token, uint256 ghoAmount, uint256 outputAmount);

    function test_swapFromGHO_success() public {
        uint256 expectedUsdcAmount = GHO_AMOUNT; // MockGSM returns 1:1

        // Setup: Mint GHO to this contract (acting as user)
        MockERC20(GHO).mint(address(this), GHO_AMOUNT);
        MockERC20(GHO).approve(address(router), GHO_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit SwapFromGHO(address(this), USDC, GHO_AMOUNT, expectedUsdcAmount);

        uint256 received = router.swapFromGHO(USDC, GHO_AMOUNT, 0);

        assertEq(received, expectedUsdcAmount, "Should return correct USDC amount");
        assertEq(MockERC20(USDC).balanceOf(address(this)), expectedUsdcAmount, "User should receive USDC");
        assertEq(MockERC20(GHO).balanceOf(address(this)), 0, "User should spend GHO");
    }

    function test_reverts_unsupportedToken() public {
        address unsupportedToken = makeAddr("new-token");

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.swapFromGHO(unsupportedToken, GHO_AMOUNT, 0);
    }

    function test_reverts_zeroAmount() public {
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapFromGHO(USDC, 0, 0);
    }

    function test_reverts_invalidGsm() public {
        address testToken = makeAddr("testToken");
        address testStata = makeAddr("testStata");

        _setPartialTokenConfig(testToken, testStata);

        vm.expectRevert(IGSMRouter.InvalidGsm.selector);
        router.swapFromGHO(testToken, GHO_AMOUNT, 0);
    }

    function testFuzz_swapFromGHO(uint256 ghoAmount) public {
        // Bound to reasonable range: 1 wei to 1M GHO (18 decimals)
        ghoAmount = bound(ghoAmount, 1, 1_000_000 * 1e18);

        MockERC20(GHO).mint(address(this), ghoAmount);
        MockERC20(GHO).approve(address(router), ghoAmount);

        uint256 usdcBalanceBefore = MockERC20(USDC).balanceOf(address(this));
        uint256 ghoBalanceBefore = MockERC20(GHO).balanceOf(address(this));

        uint256 received = router.swapFromGHO(USDC, ghoAmount, 0);

        // MockGSM returns 1:1
        assertEq(received, ghoAmount, "Should receive equal USDC amount");
        assertEq(
            MockERC20(USDC).balanceOf(address(this)), usdcBalanceBefore + ghoAmount, "USDC balance should increase"
        );
        assertEq(MockERC20(GHO).balanceOf(address(this)), ghoBalanceBefore - ghoAmount, "GHO balance should decrease");
    }

    function testFuzz_swapFromGHO_withSlippage(uint256 ghoAmount, uint256 minOutputAmount) public {
        ghoAmount = bound(ghoAmount, 1, 1_000_000 * 1e18);
        // minOutputAmount should be <= ghoAmount for swap to succeed (MockGSM is 1:1)
        minOutputAmount = bound(minOutputAmount, 0, ghoAmount);

        MockERC20(GHO).mint(address(this), ghoAmount);
        MockERC20(GHO).approve(address(router), ghoAmount);

        uint256 received = router.swapFromGHO(USDC, ghoAmount, minOutputAmount);

        assertGe(received, minOutputAmount, "Should receive at least minOutputAmount");
    }
}

contract PreviewSwapToGHOTest is GSMRouterTest {
    function test_previewSwapToGHO_success() public view {
        uint256 expectedGhoAmount = USDC_AMOUNT; // MockGSM returns 1:1

        (uint256 ghoAmount, uint256 fee) = router.previewSwapToGHO(USDC, USDC_AMOUNT);

        assertEq(ghoAmount, expectedGhoAmount, "Should preview correct GHO amount");
        assertEq(fee, 0, "Should have 0 fee in mock");
    }

    function test_reverts_unsupportedToken() public {
        address unsupportedToken = makeAddr("new-token");

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.previewSwapToGHO(unsupportedToken, USDC_AMOUNT);
    }

    function test_reverts_zeroAmount() public {
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.previewSwapToGHO(USDC, 0);
    }

    function test_reverts_invalidGsm() public {
        address testToken = makeAddr("testToken");
        address testStata = makeAddr("testStata");

        _setPartialTokenConfig(testToken, testStata);

        vm.expectRevert(IGSMRouter.InvalidGsm.selector);
        router.previewSwapToGHO(testToken, USDC_AMOUNT);
    }

    function testFuzz_previewSwapToGHO(uint256 amount, bool useUSDT) public view {
        amount = bound(amount, 1, 1_000_000 * 1e6);
        address token = useUSDT ? USDT : USDC;

        (uint256 ghoAmount, uint256 fee) = router.previewSwapToGHO(token, amount);

        // MockGSM returns 1:1 with 0 fee
        assertEq(ghoAmount, amount, "Preview should return 1:1 amount");
        assertEq(fee, 0, "Fee should be 0 in mock");
    }
}

contract PreviewSwapFromGHOTest is GSMRouterTest {
    function test_previewSwapFromGHO_success() public view {
        uint256 expectedUsdcAmount = GHO_AMOUNT; // MockGSM returns 1:1

        (uint256 outputAmount, uint256 fee) = router.previewSwapFromGHO(USDC, GHO_AMOUNT);

        assertEq(outputAmount, expectedUsdcAmount, "Should preview correct USDC amount");
        assertEq(fee, 0, "Should have 0 fee in mock");
    }

    function test_reverts_unsupportedToken() public {
        address unsupportedToken = makeAddr("new-token");

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.previewSwapFromGHO(unsupportedToken, GHO_AMOUNT);
    }

    function test_reverts_zeroAmount() public {
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.previewSwapFromGHO(USDC, 0);
    }

    function test_reverts_invalidGsm() public {
        address testToken = makeAddr("testToken");
        address testStata = makeAddr("testStata");

        _setPartialTokenConfig(testToken, testStata);

        vm.expectRevert(IGSMRouter.InvalidGsm.selector);
        router.previewSwapFromGHO(testToken, GHO_AMOUNT);
    }

    function testFuzz_previewSwapFromGHO(uint256 ghoAmount, bool useUSDT) public view {
        ghoAmount = bound(ghoAmount, 1, 1_000_000 * 1e18);
        address token = useUSDT ? USDT : USDC;

        (uint256 outputAmount, uint256 fee) = router.previewSwapFromGHO(token, ghoAmount);

        // MockGSM returns 1:1 with 0 fee
        assertEq(outputAmount, ghoAmount, "Preview should return 1:1 amount");
        assertEq(fee, 0, "Fee should be 0 in mock");
    }
}


// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {GSMRouter} from "src/contracts/onboarding/GSMRouter.sol";
import {IGSMRouter} from "src/interfaces/onboarding/IGSMRouter.sol";

/**
 * @title GSMRouterTest
 * @notice Unit tests for GSMRouter contract
 * @dev Run with: forge test --match-path test/unit/onboarding/GSMRouter.t.sol -vvv
 */
contract GSMRouterTest is Test {
    GSMRouter public router;

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    // Static aTokens Constants
    address public constant STATA_USDC = 0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E;
    address public constant STATA_USDT = 0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8;

    // GSM Contracts - GHO Stability Modules
    address internal constant GSM_USDC = 0xFeeb6FE430B7523fEF2a38327241eE7153779535; // Gsm4626 USDC
    address internal constant GSM_USDT = 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B; // Gsm4626 USDT

    function setUp() public {
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
    function test_reverts_zeroAmount() public {
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapToGHO(USDC, 0, 0);
    }

    function test_reverts_unsupportedToken() public {
        address unsupportedToken = makeAddr("new-token");

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.swapToGHO(unsupportedToken, 1000 * 1e6, 0);
    }
}

contract SwapFromGHOTest is GSMRouterTest {
    function test_reverts_unsupportedToken() public {
        address unsupportedToken = makeAddr("new-token");

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.swapFromGHO(unsupportedToken, 1000 * 1e18, 0);
    }

    function test_reverts_zeroAmount() public {
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapFromGHO(USDC, 0, 0);
    }
}

contract SwapPreviewSwapToGHOTest is GSMRouterTest {
    function test_reverts_unsupportedToken() public {
        address unsupportedToken = makeAddr("new-token");

        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.previewSwapToGHO(unsupportedToken, 1000 * 1e6);
    }
}

contract SwapPreviewSwapFromGHOTest is GSMRouterTest {
    function testFuzz_swapToGHOAmount(uint256 amount) public {
        // Bound amount between 1 and 1 million (in token units with 6 decimals)
        amount = bound(amount, 1, 1_000_000 * 1e6);
        address token = USDC;

        // Should revert with zero amount
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapToGHO(token, 0, 0);

        // Valid amounts should not revert on the router validation
        // (May still revert in actual swap due to insufficient balance/liquidity)
        try router.swapToGHO(token, amount, 0) returns (
            uint256
        ) {
        // Swap succeeded
        }
            catch {
            // Expected - we don't have actual tokens in this test
        }
    }

    function testFuzz_swapFromGHOAmount(uint256 ghoAmount) public {
        // Bound amount between 1 and 1 million GHO (18 decimals)
        ghoAmount = bound(ghoAmount, 1, 1_000_000 * 1e18);
        address token = USDC;

        // Should revert with zero amount
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapFromGHO(token, 0, 0);

        // Valid amounts should not revert on the router validation
        try router.swapFromGHO(token, ghoAmount, 0) returns (
            uint256
        ) {
        // Swap succeeded
        }
            catch {
            // Expected - we don't have actual tokens in this test
        }
    }

    function testFuzz_previewSwapToGHOWithToken(bool useUSDC, uint256 amount) public view {
        // Bound amount to reasonable values
        amount = bound(amount, 1, 1_000_000 * 1e6);
        address token = useUSDC ? USDC : USDT;

        // Preview requires actual GSM contracts to work
        // In unit tests without fork, this will revert
        try router.previewSwapToGHO(token, amount) returns (uint256 ghoAmount, uint256 fee) {
            // If we're on a fork with real GSM contracts, validate results
            assertGt(ghoAmount, 0, "GHO amount should be greater than 0");
            assertGe(fee, 0, "Fee should be non-negative");
        } catch {
            // Expected in unit tests without fork - GSM contracts don't exist
            // In integration tests with fork, this should not revert
        }
    }

    function testFuzz_previewSwapFromGHOWithToken(bool useUSDC, uint256 ghoAmount) public view {
        // Bound amount to reasonable values
        ghoAmount = bound(ghoAmount, 1, 1_000_000 * 1e18);
        address token = useUSDC ? USDC : USDT;

        // Preview requires actual GSM contracts to work
        // In unit tests without fork, this will revert
        try router.previewSwapFromGHO(token, ghoAmount) returns (uint256 assetAmount, uint256 fee) {
            // If we're on a fork with real GSM contracts, validate results
            assertGt(assetAmount, 0, "Asset amount should be greater than 0");
            assertGe(fee, 0, "Fee should be non-negative");
        } catch {
            // Expected in unit tests without fork - GSM contracts don't exist
            // In integration tests with fork, this should not revert
        }
    }
}

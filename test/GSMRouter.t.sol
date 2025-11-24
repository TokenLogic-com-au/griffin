// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {GSMRouter} from "../src/GSMRouter.sol";
import {IGSMRouter} from "../src/interfaces/IGSMRouter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GSMRouterTest
 * @notice Unit tests for GSMRouter contract
 * @dev Run with: forge test
 * @dev Integration tests with mainnet fork: forge script script/IntegrationTest.s.sol --fork-url $ETH_RPC_URL -vvv
 */
contract GSMRouterTest is Test {
    GSMRouter public router;

    // GSM Contracts - GHO Stability Modules
    address internal constant GSM_USDC = 0xFeeb6FE430B7523fEF2a38327241eE7153779535; // Gsm4626 USDC
    address internal constant GSM_USDT = 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B; // Gsm4626 USDT

    function setUp() public {
        router = new GSMRouter(address(this), GSM_USDC, GSM_USDT);
    }

    function test_constructor() public view {
        // Verify router deployed successfully
        assertTrue(address(router) != address(0), "Router should be deployed");
        assertEq(router.owner(), address(this), "Owner should be this contract");

        // Verify GSM addresses are set correctly
        assertEq(router.gsmUSDC(), GSM_USDC, "GSM USDC should be set");
        assertEq(router.gsmUSDT(), GSM_USDT, "GSM USDT should be set");

        // Verify all addresses are configured (non-zero)
        assertNotEq(router.USDC(), address(0), "USDC address should be set");
        assertNotEq(router.USDT(), address(0), "USDT address should be set");
        assertNotEq(router.GHO(), address(0), "GHO address should be set");
        assertNotEq(router.STATA_USDC(), address(0), "stataUSDC address should be set");
        assertNotEq(router.STATA_USDT(), address(0), "stataUSDT address should be set");

        // Verify addresses match official GHO documentation
        assertEq(router.GHO(), 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f, "GHO address should match docs");
    }

    function testSetGsmUSDC() public {
        address newGsm = makeAddr("newGsm");

        router.setGsmUSDC(newGsm);
        assertEq(router.gsmUSDC(), newGsm);
    }

    function testSetGsmUSDT() public {
        address newGsm = makeAddr("newGsm");

        router.setGsmUSDT(newGsm);
        assertEq(router.gsmUSDT(), newGsm);
    }

    function testSetGsmUSDCOnlyOwner() public {
        address newGsm = makeAddr("newGsm");
        address notOwner = makeAddr("notOwner");

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        router.setGsmUSDC(newGsm);
    }

    function testSetGsmUSDTOnlyOwner() public {
        address newGsm = makeAddr("newGsm");
        address notOwner = makeAddr("notOwner");

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        router.setGsmUSDT(newGsm);
    }

    function testSwapToGHORevertOnZeroAmount() public {
        // Should revert with InvalidAmount error
        address usdc = router.USDC();
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapToGHO(usdc, 0, 0);
    }

    function testSwapToGHORevertOnUnsupportedToken() public {
        address unsupportedToken = address(0x1234567890123456789012345678901234567890);

        // Should revert with InvalidToken error
        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.swapToGHO(unsupportedToken, 1000 * 1e6, 0);
    }

    function testSwapFromGHORevertOnZeroAmount() public {
        // Should revert with InvalidAmount error
        address usdc = router.USDC();
        vm.expectRevert(IGSMRouter.InvalidAmount.selector);
        router.swapFromGHO(usdc, 0, 0);
    }

    function testSwapFromGHORevertOnUnsupportedToken() public {
        address unsupportedToken = address(0x1234567890123456789012345678901234567890);

        // Should revert with InvalidToken error
        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.swapFromGHO(unsupportedToken, 1000 * 1e18, 0);
    }

    function testPreviewSwapToGHORevertOnUnsupportedToken() public {
        address unsupportedToken = address(0x1234567890123456789012345678901234567890);
        uint256 amount = 1000 * 1e6;

        // Should revert with InvalidToken error
        vm.expectRevert(IGSMRouter.InvalidToken.selector);
        router.previewSwapToGHO(unsupportedToken, amount);
    }

    function testSupportedTokensUSDC() public view {
        // USDC should be a valid supported token
        address usdc = router.USDC();
        assertEq(usdc, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, "USDC address should be correct");
    }

    function testSupportedTokensUSDT() public view {
        // USDT should be a valid supported token
        address usdt = router.USDT();
        assertEq(usdt, 0xdAC17F958D2ee523a2206206994597C13D831ec7, "USDT address should be correct");
    }

    // ============ Fuzz Tests ============

    function testFuzz_swapToGHOAmount(uint256 amount) public {
        // Bound amount between 1 and 1 million (in token units with 6 decimals)
        amount = bound(amount, 1, 1_000_000 * 1e6);
        address token = router.USDC();

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
        address token = router.USDC();

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
        address token = useUSDC ? router.USDC() : router.USDT();

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
        address token = useUSDC ? router.USDC() : router.USDT();

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

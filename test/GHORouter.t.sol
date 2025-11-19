// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {GHORouter} from "../src/GHORouter.sol";
import {Addresses} from "../src/Addresses.sol";

/**
 * @title GHORouterTest
 * @notice Unit tests for GHORouter contract
 * @dev Run with: forge test
 * @dev Integration tests with mainnet fork: forge script script/IntegrationTest.s.sol --fork-url $ETH_RPC_URL -vvv
 */
contract GHORouterTest is Test {
    GHORouter public router;

    function setUp() public {
        router = new GHORouter();
    }

    function testDeployment() public view {
        // Verify router deployed successfully
        assertTrue(address(router) != address(0), "Router should be deployed");
    }

    function testAddressesAreNonZero() public pure {
        // Verify all addresses are configured (non-zero)
        assertNotEq(Addresses.USDC, address(0), "USDC address should be set");
        assertNotEq(Addresses.USDT, address(0), "USDT address should be set");
        assertNotEq(Addresses.GHO, address(0), "GHO address should be set");
        assertNotEq(Addresses.AAVE_POOL, address(0), "Aave Pool address should be set");
        assertNotEq(Addresses.STAKED_GHO, address(0), "Staked GHO address should be set");
        assertNotEq(Addresses.STATA_USDC, address(0), "stataUSDC address should be set");
        assertNotEq(Addresses.STATA_USDT, address(0), "stataUSDT address should be set");
        assertNotEq(Addresses.GSM_USDC, address(0), "GSM USDC address should be set");
        assertNotEq(Addresses.GSM_USDT, address(0), "GSM USDT address should be set");
    }

    function testAddressesAreCorrect() public pure {
        // Verify addresses match official GHO documentation
        assertEq(Addresses.GHO, 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f, "GHO address should match docs");
        assertEq(Addresses.GSM_USDC, 0xFeeb6FE430B7523fEF2a38327241eE7153779535, "GSM USDC should match docs");
        assertEq(Addresses.GSM_USDT, 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B, "GSM USDT should match docs");
    }

    function testSwapToGHORevertOnZeroAmount() public {
        // Should revert with InvalidAmount error
        vm.expectRevert(GHORouter.InvalidAmount.selector);
        router.swapToGHO(Addresses.USDC, 0, 0);
    }

    function testSwapToGHORevertOnUnsupportedToken() public {
        address unsupportedToken = address(0x1234567890123456789012345678901234567890);

        // Should revert with InvalidToken error
        vm.expectRevert(GHORouter.InvalidToken.selector);
        router.swapToGHO(unsupportedToken, 1000 * 1e6, 0);
    }

    function testSwapFromGHORevertOnZeroAmount() public {
        // Should revert with InvalidAmount error
        vm.expectRevert(GHORouter.InvalidAmount.selector);
        router.swapFromGHO(Addresses.USDC, 0, 0);
    }

    function testSwapFromGHORevertOnUnsupportedToken() public {
        address unsupportedToken = address(0x1234567890123456789012345678901234567890);

        // Should revert with InvalidToken error
        vm.expectRevert(GHORouter.InvalidToken.selector);
        router.swapFromGHO(unsupportedToken, 1000 * 1e18, 0);
    }

    function testPreviewSwapToGHORevertOnUnsupportedToken() public {
        address unsupportedToken = address(0x1234567890123456789012345678901234567890);
        uint256 amount = 1000 * 1e6;

        // Should revert with InvalidToken error
        vm.expectRevert(GHORouter.InvalidToken.selector);
        router.previewSwapToGHO(unsupportedToken, amount);
    }

    function testSupportedTokensUSDC() public pure {
        // USDC should be a valid supported token
        address usdc = Addresses.USDC;
        assertEq(usdc, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, "USDC address should be correct");
    }

    function testSupportedTokensUSDT() public pure {
        // USDT should be a valid supported token
        address usdt = Addresses.USDT;
        assertEq(usdt, 0xdAC17F958D2ee523a2206206994597C13D831ec7, "USDT address should be correct");
    }
}

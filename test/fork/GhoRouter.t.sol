// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {GhoRouter} from "src/GhoRouter.sol";
import {IGhoRouter} from "src/interfaces/IGhoRouter.sol";
import {IGSM} from "src/interfaces/IGSM.sol";
import {sGho} from "test/fork/mocks/sGho.sol";

/**
 * @title GhoRouterTest
 * @notice Integration tests for GhoRouter on mainnet fork
 * @dev Run with: forge test --match-path test/fork/onboarding/GhoRouterTest.t.sol -vvv
 */
contract GhoRouterTest is Test {
    GhoRouter public router;
    sGho public sgho;

    // https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // https://etherscan.io/address/0xdAC17F958D2ee523a2206206994597C13D831ec7
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    // https://etherscan.io/address/0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    // Static aTokens Constants
    // https://etherscan.io/address/0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E
    address public constant STATA_USDC = 0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E;
    // https://etherscan.io/address/0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8
    address public constant STATA_USDT = 0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8;

    // Addresses needed for test setup
    // https://etherscan.io/address/0xFeeb6FE430B7523fEF2a38327241eE7153779535
    address constant GSM_USDC = 0xFeeb6FE430B7523fEF2a38327241eE7153779535;
    // https://etherscan.io/address/0x535b2f7C20B9C83d70e519cf9991578eF9816B7B
    address constant GSM_USDT = 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B;

    // Test user address
    address constant USER = address(0xF00DBA11);
    address constant RECIPIENT = address(0xCAFEF00D);
    uint256 constant MAINNET_FORK_BLOCK = 24_001_794;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), MAINNET_FORK_BLOCK);

        sGho sghoImpl = new sGho();
        sgho = sGho(
            address(
                new ERC1967Proxy(
                    address(sghoImpl), abi.encodeCall(sGho.initialize, (GHO, type(uint160).max, address(this)))
                )
            )
        );
        router = new GhoRouter(address(this), GHO, address(sgho));
        router.setGsmAllowed(GSM_USDC, true);
        router.setGsmAllowed(GSM_USDT, true);
    }
}

contract GsmWhitelistTest is GhoRouterTest {
    function test_owner_can_update_gsm_whitelist() public {
        router.setGsmAllowed(GSM_USDC, false);
        assertFalse(router.isGsmAllowed(GSM_USDC));

        router.setGsmAllowed(GSM_USDC, true);
        assertTrue(router.isGsmAllowed(GSM_USDC));
    }

    function test_reverts_non_owner_update_gsm_whitelist() public {
        vm.startPrank(USER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, USER));
        router.setGsmAllowed(GSM_USDC, false);
        vm.stopPrank();
    }
}

contract SwapToGHOTest is GhoRouterTest {
    function test_swap_usdc_to_gho() public {
        uint256 usdcAmount = 1000 * 1e6; // 1000 USDC
        deal(USDC, USER, usdcAmount);

        vm.startPrank(USER);

        IERC20(USDC).approve(address(router), usdcAmount);
        vm.expectEmit(true, true, false, false);
        emit IGhoRouter.SwapToGHO(USER, USDC, 0, 0);
        uint256 ghoReceived = router.swapToGHO(GSM_USDC, USDC, usdcAmount, 0);

        assertGt(ghoReceived, 0, "Should receive GHO");

        vm.stopPrank();
    }

    function test_swap_usdt_to_gho() public {
        uint256 usdtAmount = 1000 * 1e6; // 1000 USDT
        deal(USDT, USER, usdtAmount);

        vm.startPrank(USER);

        SafeERC20.forceApprove(IERC20(USDT), address(router), usdtAmount);
        vm.expectEmit(true, true, false, false);
        emit IGhoRouter.SwapToGHO(USER, USDT, 0, 0);
        uint256 ghoReceived = router.swapToGHO(GSM_USDT, USDT, usdtAmount, 0);

        assertGt(ghoReceived, 0, "Should receive GHO");

        vm.stopPrank();
    }

    function test_swap_usdc_to_gho_with_recipient() public {
        uint256 usdcAmount = 1000 * 1e6;
        deal(USDC, USER, usdcAmount);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(router), usdcAmount);

        uint256 recipientBalanceBefore = IERC20(GHO).balanceOf(RECIPIENT);
        uint256 userBalanceBefore = IERC20(GHO).balanceOf(USER);
        uint256 ghoReceived = router.swapToGHO(GSM_USDC, USDC, usdcAmount, 0, RECIPIENT);
        vm.stopPrank();

        assertGt(ghoReceived, 0, "Should receive GHO");
        assertEq(IERC20(GHO).balanceOf(RECIPIENT) - recipientBalanceBefore, ghoReceived, "Recipient gets GHO");
        assertEq(IERC20(GHO).balanceOf(USER), userBalanceBefore, "Caller should not receive GHO");
    }

    function test_reverts_swap_to_gho_zero_amount() public {
        vm.startPrank(USER);
        vm.expectRevert(IGhoRouter.InvalidAmount.selector);
        router.swapToGHO(GSM_USDC, USDC, 0, 0);
        vm.stopPrank();
    }

    function test_reverts_swap_to_gho_slippage_exceeded() public {
        uint256 usdcAmount = 1000 * 1e6; // 1000 USDC
        deal(USDC, USER, usdcAmount);

        vm.startPrank(USER);

        IERC20(USDC).approve(address(router), usdcAmount);

        // Set unreasonably high minGHOAmount to trigger slippage
        vm.expectRevert(IGhoRouter.SlippageExceeded.selector);
        router.swapToGHO(GSM_USDC, USDC, usdcAmount, type(uint256).max);

        vm.stopPrank();
    }

    function test_reverts_swap_to_gho_gsm_not_allowed() public {
        router.setGsmAllowed(GSM_USDC, false);

        vm.startPrank(USER);
        vm.expectRevert(IGhoRouter.GsmNotAllowed.selector);
        router.swapToGHO(GSM_USDC, USDC, 1, 0);
        vm.stopPrank();
    }

    function test_reverts_swap_to_gho_invalid_token() public {
        vm.startPrank(USER);
        vm.expectRevert(IGhoRouter.InvalidToken.selector);
        router.swapToGHO(GSM_USDC, GHO, 1, 0);
        vm.stopPrank();
    }

    function test_reverts_swap_to_gho_zero_recipient() public {
        vm.startPrank(USER);
        vm.expectRevert(IGhoRouter.ZeroAddress.selector);
        router.swapToGHO(GSM_USDC, USDC, 1, 0, address(0));
        vm.stopPrank();
    }
}

contract SwapFromGHOTest is GhoRouterTest {
    function test_swap_gho_to_usdc() public {
        uint256 ghoAmount = 100 ether;

        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);

        IERC20(GHO).approve(address(router), ghoAmount);
        vm.expectEmit(true, true, false, false);
        emit IGhoRouter.SwapFromGHO(USER, USDC, 0, 0);
        uint256 usdcReceived = router.swapFromGHO(GSM_USDC, ghoAmount, 0);

        assertGt(usdcReceived, 0, "Should receive USDC");

        vm.stopPrank();
    }

    function test_swap_gho_to_usdt() public {
        uint256 ghoAmount = 100 ether;

        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);

        IERC20(GHO).approve(address(router), ghoAmount);
        vm.expectEmit(true, true, false, false);
        emit IGhoRouter.SwapFromGHO(USER, USDT, 0, 0);
        uint256 usdtReceived = router.swapFromGHO(GSM_USDT, ghoAmount, 0);

        assertGt(usdtReceived, 0, "Should receive USDT");

        vm.stopPrank();
    }

    function test_swap_gho_to_stata_usdc() public {
        uint256 ghoAmount = 100 ether;
        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(router), ghoAmount);

        uint256 userBalanceBefore = IERC20(STATA_USDC).balanceOf(USER);
        vm.expectEmit(true, true, false, false);
        emit IGhoRouter.SwapFromGHO(USER, STATA_USDC, 0, 0);
        uint256 stataReceived = router.swapFromGHO(GSM_USDC, STATA_USDC, ghoAmount, 1);
        vm.stopPrank();

        assertGt(stataReceived, 0, "Should receive static aToken");
        assertEq(IERC20(STATA_USDC).balanceOf(USER) - userBalanceBefore, stataReceived, "User gets static aToken");
    }

    function test_swap_gho_to_usdc_with_recipient() public {
        uint256 ghoAmount = 100 ether;

        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(router), ghoAmount);

        uint256 recipientBalanceBefore = IERC20(USDC).balanceOf(RECIPIENT);
        uint256 userBalanceBefore = IERC20(USDC).balanceOf(USER);
        uint256 usdcReceived = router.swapFromGHO(GSM_USDC, ghoAmount, 0, RECIPIENT);
        vm.stopPrank();

        assertGt(usdcReceived, 0, "Should receive USDC");
        assertEq(IERC20(USDC).balanceOf(RECIPIENT) - recipientBalanceBefore, usdcReceived, "Recipient gets USDC");
        assertEq(IERC20(USDC).balanceOf(USER), userBalanceBefore, "Caller should not receive USDC");
    }

    function test_reverts_swap_from_gho_zero_amount() public {
        vm.startPrank(USER);
        vm.expectRevert(IGhoRouter.InvalidAmount.selector);
        router.swapFromGHO(GSM_USDC, 0, 0);
        vm.stopPrank();
    }

    function test_reverts_swap_from_gho_slippage_exceeded() public {
        uint256 ghoAmount = 100 ether;

        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);

        IERC20(GHO).approve(address(router), ghoAmount);

        // Set unreasonably high minOutputAmount to trigger slippage
        vm.expectRevert(IGhoRouter.SlippageExceeded.selector);
        router.swapFromGHO(GSM_USDC, ghoAmount, type(uint256).max);

        vm.stopPrank();
    }

    function test_reverts_swap_from_gho_gsm_not_allowed() public {
        router.setGsmAllowed(GSM_USDC, false);

        vm.startPrank(USER);
        vm.expectRevert(IGhoRouter.GsmNotAllowed.selector);
        router.swapFromGHO(GSM_USDC, 1, 0);
        vm.stopPrank();
    }

    function test_reverts_swap_from_gho_invalid_token() public {
        vm.startPrank(USER);
        vm.expectRevert(IGhoRouter.InvalidToken.selector);
        router.swapFromGHO(GSM_USDC, GHO, 1 ether, 0);
        vm.stopPrank();
    }

    function test_reverts_swap_from_gho_zero_recipient() public {
        uint256 ghoAmount = 1 ether;
        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(router), ghoAmount);
        vm.expectRevert(IGhoRouter.ZeroAddress.selector);
        router.swapFromGHO(GSM_USDC, ghoAmount, 0, address(0));
        vm.stopPrank();
    }

    function test_preview_swap_to_gho() public view {
        uint256 usdcAmount = 1000 * 1e6; // 1000 USDC

        (uint256 ghoAmount, uint256 fee) = router.previewSwapToGHO(GSM_USDC, USDC, usdcAmount);

        assertGt(ghoAmount, 0, "Should preview GHO amount");
        // Fee might be zero depending on GSM config, so we just check it doesn't revert
        assertGe(fee, 0);
    }

    function test_preview_swap_from_gho() public view {
        uint256 ghoAmount = 1000 * 1e18; // 1000 GHO

        (uint256 outputAmount, uint256 fee) = router.previewSwapFromGHO(GSM_USDC, ghoAmount);

        assertGt(outputAmount, 0, "Should preview output amount");
        assertGe(fee, 0);
    }

    function test_preview_swap_from_gho_to_stata() public view {
        uint256 ghoAmount = 1000 * 1e18;

        (uint256 outputAmount, uint256 fee) = router.previewSwapFromGHO(GSM_USDC, STATA_USDC, ghoAmount);

        assertGt(outputAmount, 0, "Should preview static aToken output amount");
        assertGe(fee, 0);
    }
}

contract SwapTosGHOTest is GhoRouterTest {
    function test_swap_usdc_to_sgho() public {
        uint256 usdcAmount = 1000 * 1e6;
        deal(USDC, USER, usdcAmount);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(router), usdcAmount);
        vm.expectEmit(true, true, true, false);
        emit IGhoRouter.SwapTosGHO(USER, USDC, address(sgho), 0, 0, 0);
        uint256 shares = router.swapTosGHO(GSM_USDC, USDC, usdcAmount, 1);
        vm.stopPrank();

        assertGt(shares, 0, "Should receive sGHO shares");
        assertEq(IERC20(address(sgho)).balanceOf(USER), shares, "User should receive minted shares");
    }

    function test_swap_usdt_to_sgho() public {
        uint256 usdtAmount = 1000 * 1e6;
        deal(USDT, USER, usdtAmount);

        vm.startPrank(USER);
        SafeERC20.forceApprove(IERC20(USDT), address(router), usdtAmount);
        vm.expectEmit(true, true, true, false);
        emit IGhoRouter.SwapTosGHO(USER, USDT, address(sgho), 0, 0, 0);
        uint256 shares = router.swapTosGHO(GSM_USDT, USDT, usdtAmount, 1);
        vm.stopPrank();

        assertGt(shares, 0, "Should receive sGHO shares");
        assertEq(IERC20(address(sgho)).balanceOf(USER), shares, "User should receive minted shares");
    }

    function test_swap_gho_to_sgho() public {
        uint256 ghoAmount = 100 ether;

        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(router), ghoAmount);
        vm.expectEmit(true, true, true, true);
        emit IGhoRouter.SwapTosGHO(USER, GHO, address(sgho), ghoAmount, ghoAmount, ghoAmount);
        uint256 shares = router.swapTosGHO(ghoAmount, ghoAmount);
        vm.stopPrank();

        assertEq(shares, ghoAmount, "sGHO copy should mint 1:1 shares at initial index");
        assertEq(IERC20(address(sgho)).balanceOf(USER), ghoAmount, "User should receive all shares");
    }

    function test_swap_gho_to_sgho_with_recipient() public {
        uint256 ghoAmount = 100 ether;

        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(router), ghoAmount);
        uint256 recipientBalanceBefore = IERC20(address(sgho)).balanceOf(RECIPIENT);
        uint256 userBalanceBefore = IERC20(address(sgho)).balanceOf(USER);
        uint256 shares = router.swapTosGHO(ghoAmount, ghoAmount, RECIPIENT);
        vm.stopPrank();

        assertEq(shares, ghoAmount, "sGHO copy should mint 1:1 shares at initial index");
        assertEq(
            IERC20(address(sgho)).balanceOf(RECIPIENT) - recipientBalanceBefore,
            shares,
            "Recipient should receive shares"
        );
        assertEq(IERC20(address(sgho)).balanceOf(USER), userBalanceBefore, "Caller should not receive shares");
    }

    function test_preview_swap_to_sgho() public view {
        uint256 usdcAmount = 1000 * 1e6;

        (uint256 sghoAmount, uint256 fee) = router.previewSwapTosGHO(GSM_USDC, USDC, usdcAmount);

        assertGt(sghoAmount, 0, "Should preview sGHO amount");
        assertGe(fee, 0, "Fee check should not revert");
    }

    function test_reverts_swap_to_sgho_gsm_not_allowed() public {
        router.setGsmAllowed(GSM_USDC, false);

        vm.startPrank(USER);
        vm.expectRevert(IGhoRouter.GsmNotAllowed.selector);
        router.swapTosGHO(GSM_USDC, USDC, 1, 0);
        vm.stopPrank();
    }

    function test_reverts_swap_to_sgho_zero_recipient() public {
        uint256 ghoAmount = 1 ether;
        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(router), ghoAmount);
        vm.expectRevert(IGhoRouter.ZeroAddress.selector);
        router.swapTosGHO(ghoAmount, 0, address(0));
        vm.stopPrank();
    }
}

contract SwapFromsGHOTest is GhoRouterTest {
    function _mintSgho(uint256 ghoAmount) internal {
        deal(GHO, USER, ghoAmount);
        vm.startPrank(USER);
        IERC20(GHO).approve(address(sgho), ghoAmount);
        sgho.deposit(ghoAmount, USER);
        vm.stopPrank();
    }

    function test_swap_sgho_to_gho() public {
        uint256 ghoAmount = 100 ether;
        _mintSgho(ghoAmount);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(router), ghoAmount);
        vm.expectEmit(true, true, true, true);
        emit IGhoRouter.SwapFromsGHO(USER, address(sgho), GHO, ghoAmount, ghoAmount, ghoAmount);
        uint256 outputAmount = router.swapFromsGHO(ghoAmount, ghoAmount);
        vm.stopPrank();

        assertEq(outputAmount, ghoAmount, "Should redeem to full GHO amount");
        assertEq(IERC20(GHO).balanceOf(USER), ghoAmount, "User should receive redeemed GHO");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "User should spend all sGHO");
    }

    function test_swap_sgho_to_gho_with_recipient() public {
        uint256 ghoAmount = 100 ether;
        _mintSgho(ghoAmount);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(router), ghoAmount);
        uint256 recipientBalanceBefore = IERC20(GHO).balanceOf(RECIPIENT);
        uint256 userBalanceBefore = IERC20(GHO).balanceOf(USER);
        uint256 outputAmount = router.swapFromsGHO(ghoAmount, ghoAmount, RECIPIENT);
        vm.stopPrank();

        assertEq(outputAmount, ghoAmount, "Should redeem to full GHO amount");
        assertEq(
            IERC20(GHO).balanceOf(RECIPIENT) - recipientBalanceBefore, outputAmount, "Recipient should receive GHO"
        );
        assertEq(IERC20(GHO).balanceOf(USER), userBalanceBefore, "Caller should not receive GHO");
    }

    function test_swap_sgho_to_usdc() public {
        uint256 ghoAmount = 100 ether;
        _mintSgho(ghoAmount);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(router), ghoAmount);
        vm.expectEmit(true, true, true, false);
        emit IGhoRouter.SwapFromsGHO(USER, address(sgho), USDC, 0, 0, 0);
        uint256 outputAmount = router.swapFromsGHO(GSM_USDC, ghoAmount, 1);
        vm.stopPrank();

        assertGt(outputAmount, 0, "Should receive USDC");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "User should spend all sGHO");
    }

    function test_swap_sgho_to_stata_usdc() public {
        uint256 ghoAmount = 100 ether;
        _mintSgho(ghoAmount);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(router), ghoAmount);
        uint256 userBalanceBefore = IERC20(STATA_USDC).balanceOf(USER);
        vm.expectEmit(true, true, true, false);
        emit IGhoRouter.SwapFromsGHO(USER, address(sgho), STATA_USDC, 0, 0, 0);
        uint256 outputAmount = router.swapFromsGHO(GSM_USDC, STATA_USDC, ghoAmount, 1);
        vm.stopPrank();

        assertGt(outputAmount, 0, "Should receive static aToken");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "User should spend all sGHO");
        assertEq(
            IERC20(STATA_USDC).balanceOf(USER) - userBalanceBefore,
            outputAmount,
            "User should receive static aToken output"
        );
    }

    function test_reverts_swap_from_sgho_zero_amount() public {
        vm.startPrank(USER);
        vm.expectRevert(IGhoRouter.InvalidAmount.selector);
        router.swapFromsGHO(GSM_USDC, 0, 0);
        vm.stopPrank();
    }

    function test_reverts_swap_from_sgho_zero_recipient() public {
        _mintSgho(1 ether);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(router), 1 ether);
        vm.expectRevert(IGhoRouter.ZeroAddress.selector);
        router.swapFromsGHO(1 ether, 0, address(0));
        vm.stopPrank();
    }

    function test_preview_swap_from_sgho_to_gho() public view {
        uint256 shareAmount = 100 ether;

        uint256 outputAmount = router.previewSwapFromsGHO(shareAmount);

        assertEq(outputAmount, shareAmount, "sGHO copy preview should be 1:1 at initial index");
    }

    function test_preview_swap_from_sgho_to_usdc() public view {
        uint256 shareAmount = 100 ether;

        (uint256 outputAmount, uint256 fee) = router.previewSwapFromsGHO(GSM_USDC, shareAmount);

        assertGt(outputAmount, 0, "Should preview USDC output");
        assertGe(fee, 0, "Fee check should not revert");
    }

    function test_reverts_swap_from_sgho_to_usdc_gsm_not_allowed() public {
        router.setGsmAllowed(GSM_USDC, false);
        _mintSgho(100 ether);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(router), 100 ether);
        vm.expectRevert(IGhoRouter.GsmNotAllowed.selector);
        router.swapFromsGHO(GSM_USDC, 100 ether, 0);
        vm.stopPrank();
    }

    function test_reverts_swap_from_sgho_invalid_token() public {
        _mintSgho(1 ether);

        vm.startPrank(USER);
        IERC20(address(sgho)).approve(address(router), 1 ether);
        vm.expectRevert(IGhoRouter.InvalidToken.selector);
        router.swapFromsGHO(GSM_USDC, GHO, 1 ether, 0);
        vm.stopPrank();
    }

    function test_preview_swap_from_sgho_to_stata() public view {
        uint256 shareAmount = 100 ether;

        (uint256 outputAmount, uint256 fee) = router.previewSwapFromsGHO(GSM_USDC, STATA_USDC, shareAmount);

        assertGt(outputAmount, 0, "Should preview static aToken output");
        assertGe(fee, 0, "Fee check should not revert");
    }
}

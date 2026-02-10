// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {GSMRouter} from "src/contracts/onboarding/GSMRouter.sol";
import {sGHORouter} from "src/contracts/onboarding/SGHORouter.sol";
import {MockSGHO} from "test/mocks/MockSGHO.sol";

/**
 * @title SGHORouterForkTest
 * @notice Mainnet-fork integration tests for SGHORouter token paths.
 * @dev Deploys fresh GSMRouter + SGHORouter on fork.
 */
contract SGHORouterForkTest is Test {
    using SafeERC20 for IERC20;

    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    address internal constant GSM_USDC = 0xFeeb6FE430B7523fEF2a38327241eE7153779535;
    address internal constant GSM_USDT = 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B;

    address internal constant USER = address(0xBEEF);

    GSMRouter internal gsmRouter;
    MockSGHO internal sgho;
    sGHORouter internal helper;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        gsmRouter = new GSMRouter(address(this), GHO);
        sgho = new MockSGHO(GHO);
        helper = new sGHORouter(address(gsmRouter), address(sgho), GHO, USDC, USDT, GSM_USDC, GSM_USDT);
    }

    function test_roundTrip_USDC() public {
        uint256 usdcAmount = 1_000 * 1e6;

        _primeSwapToGhoCapacity(GSM_USDC);
        deal(USDC, USER, usdcAmount);

        vm.startPrank(USER);
        IERC20(USDC).approve(address(helper), usdcAmount);
        uint256 shares = helper.deposit(USDC, usdcAmount);
        assertGt(shares, 0, "USDC deposit should mint shares");

        IERC20(address(sgho)).approve(address(helper), shares);
        uint256 usdcOut = helper.redeem(shares, USDC);
        vm.stopPrank();

        assertGt(usdcOut, 0, "USDC redeem output should be > 0");
        assertEq(IERC20(USDC).balanceOf(USER), usdcOut, "USER should receive redeemed USDC");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "USER should have no shares after full redeem");
        _assertNoCustody();
    }

    function test_roundTrip_USDT() public {
        uint256 usdtAmount = 1_000 * 1e6;

        _primeSwapToGhoCapacity(GSM_USDT);
        deal(USDT, USER, usdtAmount);

        vm.startPrank(USER);
        SafeERC20.forceApprove(IERC20(USDT), address(helper), usdtAmount);
        uint256 shares = helper.deposit(USDT, usdtAmount);
        assertGt(shares, 0, "USDT deposit should mint shares");

        IERC20(address(sgho)).approve(address(helper), shares);
        uint256 usdtOut = helper.redeem(shares, USDT);
        vm.stopPrank();

        assertGt(usdtOut, 0, "USDT redeem output should be > 0");
        assertEq(IERC20(USDT).balanceOf(USER), usdtOut, "USER should receive redeemed USDT");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "USER should have no shares after full redeem");
        _assertNoCustody();
    }

    function test_roundTrip_GHO() public {
        uint256 ghoAmount = 100 ether;

        deal(GHO, USER, ghoAmount);

        vm.startPrank(USER);
        IERC20(GHO).approve(address(helper), ghoAmount);
        uint256 shares = helper.deposit(GHO, ghoAmount);
        assertEq(shares, ghoAmount, "mock sGHO is 1:1");

        IERC20(address(sgho)).approve(address(helper), shares);
        uint256 ghoOut = helper.redeem(shares, GHO);
        vm.stopPrank();

        assertEq(ghoOut, ghoAmount, "GHO round-trip should be 1:1 through mock sGHO");
        assertEq(IERC20(GHO).balanceOf(USER), ghoAmount, "USER should receive redeemed GHO");
        assertEq(IERC20(address(sgho)).balanceOf(USER), 0, "USER should have no shares after full redeem");
        _assertNoCustody();
    }

    function _assertNoCustody() internal view {
        assertEq(IERC20(USDC).balanceOf(address(helper)), 0, "helper should keep no USDC");
        assertEq(IERC20(USDT).balanceOf(address(helper)), 0, "helper should keep no USDT");
        assertEq(IERC20(GHO).balanceOf(address(helper)), 0, "helper should keep no GHO");
        assertEq(IERC20(address(sgho)).balanceOf(address(helper)), 0, "helper should keep no sGHO");
    }

    function _primeSwapToGhoCapacity(address gsm) internal {
        uint256[4] memory ghoAttempts =
            [uint256(5_000 ether), uint256(1_000 ether), uint256(100 ether), uint256(10 ether)];

        for (uint256 i = 0; i < ghoAttempts.length; i++) {
            uint256 ghoAmount = ghoAttempts[i];
            deal(GHO, USER, ghoAmount);

            vm.startPrank(USER);
            IERC20(GHO).approve(address(gsmRouter), ghoAmount);
            try gsmRouter.swapFromGHO(gsm, ghoAmount, 0) {
                vm.stopPrank();
                return;
            } catch {
                vm.stopPrank();
            }
        }

        revert("failed to prime GSM");
    }
}

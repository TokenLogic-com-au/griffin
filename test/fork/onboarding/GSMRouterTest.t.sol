// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IGSM} from "src/interfaces/IGSM.sol";
import {GSMRouter} from "src/contracts/onboarding/GSMRouter.sol";

/**
 * @title GSMRouterTest
 * @notice Integration tests for GSMRouter on mainnet fork
 * @dev Run with: forge test --match-path test/fork/onboarding/GSMRouterTest.t.sol -vvv
 */
contract GSMRouterTest is Script {
    using SafeERC20 for IERC20;

    GSMRouter public router;

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    // Static aTokens Constants
    address public constant STATA_USDC =
        0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E;
    address public constant STATA_USDT =
        0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8;

    // Addresses needed for test setup
    address constant GSM_USDC = 0xFeeb6FE430B7523fEF2a38327241eE7153779535;
    address constant GSM_USDT = 0x535b2f7C20B9C83d70e519cf9991578eF9816B7B;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        router = new GSMRouter(msg.sender, GSM_USDC, GSM_USDT);

        deal(address(this), router.USDC(), 10_000_000e6);
        deal(address(this), router.USDT(), 10_000_000e6);
    }

    function test_constructor() public {}
}

contract SwapToGHOTest is GSMRouterTest {
    function testSwapUSDCToGHO() public {
        uint256 usdcAmount = 1000 * 1e6; // 1000 USDC
        address user = USDC_WHALE;
        address usdc = router.USDC();

        vm.startPrank(user);

        uint256 initialUsdc = IERC20(usdc).balanceOf(user);
        require(initialUsdc >= usdcAmount, "Whale should have enough USDC");

        IERC20(usdc).approve(address(router), usdcAmount);
        uint256 ghoReceived = router.swapToGHO(usdc, usdcAmount, 0);

        // this should be assert, not require
        require(ghoReceived > 0, "Should receive GHO");

        vm.stopPrank();
    }

    function testSwapUSDTToGHO() public {
        uint256 usdtAmount = 1000 * 1e6; // 1000 USDT
        address user = USDT_WHALE;
        address usdt = router.USDT();

        vm.startPrank(user);

        uint256 initialUsdt = IERC20(usdt).balanceOf(user);
        require(initialUsdt >= usdtAmount, "Whale should have enough USDT");

        IERC20(usdt).forceApprove(address(router), usdtAmount);
        uint256 ghoReceived = router.swapToGHO(usdt, usdtAmount, 0);
        require(ghoReceived > 0, "Should receive GHO");

        vm.stopPrank();
    }

    function testSwapGHOToUSDC() public {
        uint256 ghoAmount = 100 ether;
        address user = GHO_WHALE;
        address gho = router.GHO();
        address usdc = router.USDC();

        vm.startPrank(user);

        uint256 initialGho = IERC20(gho).balanceOf(user);
        require(initialGho >= ghoAmount, "Whale should have enough GHO");

        IERC20(gho).approve(address(router), ghoAmount);
        uint256 usdcReceived = router.swapFromGHO(usdc, ghoAmount, 0);
        require(usdcReceived > 0, "Should receive USDC");

        vm.stopPrank();
    }

    function testSwapGHOToUSDT() public {
        uint256 ghoAmount = 100 ether;
        address user = GHO_WHALE;
        address gho = router.GHO();
        address usdt = router.USDT();

        vm.startPrank(user);

        uint256 initialGho = IERC20(gho).balanceOf(user);
        require(initialGho >= ghoAmount, "Whale should have enough GHO");

        IERC20(gho).approve(address(router), ghoAmount);
        uint256 usdtReceived = router.swapFromGHO(usdt, ghoAmount, 0);
        require(usdtReceived > 0, "Should receive USDT");

        vm.stopPrank();
    }
}

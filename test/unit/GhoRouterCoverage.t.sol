// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {GhoRouter} from "src/GhoRouter.sol";
import {IGSM} from "src/interfaces/IGSM.sol";
import {IGhoRouter} from "src/interfaces/IGhoRouter.sol";

contract MockERC20 is ERC20 {
    uint8 internal immutable _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockVaultToken is ERC20 {
    IERC20 internal immutable _asset;

    constructor(string memory name_, string memory symbol_, address asset_) ERC20(name_, symbol_) {
        _asset = IERC20(asset_);
    }

    function asset() external view returns (address) {
        return address(_asset);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256) {
        _asset.transferFrom(msg.sender, address(this), assets);
        _mint(receiver, assets);
        return assets;
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256) {
        if (owner != msg.sender) {
            _spendAllowance(owner, msg.sender, shares);
        }
        _burn(owner, shares);
        _asset.transfer(receiver, shares);
        return shares;
    }

    function previewDeposit(uint256 assets) external pure returns (uint256) {
        return assets;
    }

    function previewRedeem(uint256 shares) external pure returns (uint256) {
        return shares;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockBadStaticToken {
    function asset() external pure returns (address) {
        return address(0);
    }
}

contract MockGSM is IGSM {
    address public immutable override GHO_TOKEN;
    address public immutable override UNDERLYING_ASSET;

    uint256 public sellFillBps = 10_000;

    constructor(address ghoToken_, address underlyingAsset_) {
        GHO_TOKEN = ghoToken_;
        UNDERLYING_ASSET = underlyingAsset_;
    }

    function setSellFillBps(uint256 fillBps) external {
        sellFillBps = fillBps;
    }

    function buyAsset(uint256 minAmount, address receiver) external returns (uint256, uint256) {
        uint256 ghoSold = minAmount;
        IERC20(GHO_TOKEN).transferFrom(msg.sender, address(this), ghoSold);
        IERC20(UNDERLYING_ASSET).transfer(receiver, minAmount);
        return (minAmount, ghoSold);
    }

    function sellAsset(uint256 maxAmount, address receiver) external returns (uint256, uint256) {
        uint256 assetSold = maxAmount * sellFillBps / 10_000;
        IERC20(UNDERLYING_ASSET).transferFrom(msg.sender, address(this), assetSold);
        uint256 ghoBought = assetSold;
        IERC20(GHO_TOKEN).transfer(receiver, ghoBought);
        return (assetSold, ghoBought);
    }

    function getAssetAmountForBuyAsset(uint256 maxGhoAmount) external pure returns (uint256, uint256, uint256, uint256) {
        return (maxGhoAmount, maxGhoAmount, maxGhoAmount, 0);
    }

    function getGhoAmountForSellAsset(uint256 maxAssetAmount) external view returns (uint256, uint256, uint256, uint256) {
        uint256 sold = maxAssetAmount * sellFillBps / 10_000;
        return (sold, sold, sold, 0);
    }
}

contract GhoRouterTest is Test {
    address internal constant USER = address(0x1);
    address internal constant RECIPIENT = address(0x2);

    MockERC20 internal gho;
    MockERC20 internal underlying;
    MockVaultToken internal stataToken;
    MockVaultToken internal sgho;
    MockGSM internal gsm;
    GhoRouter internal router;

    function setUp() public {
        gho = new MockERC20("GHO", "GHO", 18);
        underlying = new MockERC20("USD Coin", "USDC", 18);

        stataToken = new MockVaultToken("Static USDC", "sUSDC", address(underlying));
        sgho = new MockVaultToken("sGHO", "sGHO", address(gho));
        gsm = new MockGSM(address(gho), address(stataToken));

        router = new GhoRouter(address(this), address(gho), address(sgho));
        router.setGsmAllowed(address(gsm), true);

        gho.mint(address(gsm), 1_000_000e18);
        underlying.mint(address(stataToken), 1_000_000e18);
        stataToken.mint(address(gsm), 1_000_000e18);
    }

    function _mintAndApproveGho(uint256 amount) internal {
        gho.mint(USER, amount);
        vm.prank(USER);
        IERC20(address(gho)).approve(address(router), type(uint256).max);
    }

    function _mintAndApproveUnderlying(uint256 amount) internal {
        underlying.mint(USER, amount);
        vm.prank(USER);
        IERC20(address(underlying)).approve(address(router), type(uint256).max);
    }

    function _mintSghoAndApprove(uint256 ghoAmount) internal {
        gho.mint(USER, ghoAmount);
        vm.startPrank(USER);
        IERC20(address(gho)).approve(address(sgho), ghoAmount);
        sgho.deposit(ghoAmount, USER);
        IERC20(address(sgho)).approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function test_constructor_reverts_for_zero_gho() public {
        vm.expectRevert(IGhoRouter.ZeroAddress.selector);
        new GhoRouter(address(this), address(0), address(sgho));
    }

    function test_constructor_reverts_for_zero_sgho() public {
        vm.expectRevert(IGhoRouter.ZeroAddress.selector);
        new GhoRouter(address(this), address(gho), address(0));
    }

    function test_reverts_set_gsm_allowed_zero_address() public {
        vm.expectRevert(IGhoRouter.ZeroAddress.selector);
        router.setGsmAllowed(address(0), true);
    }

    function test_reverts_set_gsm_allowed_for_eoa() public {
        vm.expectRevert(IGhoRouter.InvalidGsm.selector);
        router.setGsmAllowed(USER, true);
    }

    function test_reverts_set_gsm_allowed_for_wrong_gho() public {
        MockERC20 wrongGho = new MockERC20("Wrong GHO", "WGHO", 18);
        MockGSM wrongGsm = new MockGSM(address(wrongGho), address(stataToken));

        vm.expectRevert(IGhoRouter.InvalidGsm.selector);
        router.setGsmAllowed(address(wrongGsm), true);
    }

    function test_reverts_set_gsm_allowed_for_zero_underlying_asset() public {
        MockGSM wrongGsm = new MockGSM(address(gho), address(0));

        vm.expectRevert(IGhoRouter.InvalidGsm.selector);
        router.setGsmAllowed(address(wrongGsm), true);
    }

    function test_reverts_set_gsm_allowed_for_invalid_static_asset() public {
        MockBadStaticToken badStatic = new MockBadStaticToken();
        MockGSM wrongGsm = new MockGSM(address(gho), address(badStatic));

        vm.expectRevert(IGhoRouter.InvalidToken.selector);
        router.setGsmAllowed(address(wrongGsm), true);
    }

    function test_owner_can_rescue_token() public {
        uint256 amount = 10e18;
        underlying.mint(address(router), amount);

        uint256 recipientBefore = underlying.balanceOf(RECIPIENT);
        router.rescueToken(address(underlying), RECIPIENT, amount);

        assertEq(underlying.balanceOf(RECIPIENT) - recipientBefore, amount);
    }

    function test_reverts_preview_swap_to_gho_zero_amount() public {
        vm.expectRevert(IGhoRouter.InvalidAmount.selector);
        router.previewSwapToGHO(address(gsm), address(underlying), 0);
    }

    function test_reverts_preview_swap_from_gho_zero_amount() public {
        vm.expectRevert(IGhoRouter.InvalidAmount.selector);
        router.previewSwapFromGHO(address(gsm), 0);
    }

    function test_reverts_preview_swap_from_gho_to_token_zero_amount() public {
        vm.expectRevert(IGhoRouter.InvalidAmount.selector);
        router.previewSwapFromGHO(address(gsm), address(underlying), 0);
    }

    function test_reverts_preview_swap_to_sgho_zero_amount() public {
        vm.expectRevert(IGhoRouter.InvalidAmount.selector);
        router.previewSwapTosGHO(address(gsm), address(underlying), 0);
    }

    function test_reverts_preview_direct_to_sgho_zero_amount() public {
        vm.expectRevert(IGhoRouter.InvalidAmount.selector);
        router.previewSwapTosGHO(0);
    }

    function test_preview_direct_to_sgho() public view {
        assertEq(router.previewSwapTosGHO(5e18), 5e18);
    }

    function test_reverts_preview_swap_from_sgho_zero_amount() public {
        vm.expectRevert(IGhoRouter.InvalidAmount.selector);
        router.previewSwapFromsGHO(address(gsm), 0);
    }

    function test_reverts_preview_swap_from_sgho_to_token_zero_amount() public {
        vm.expectRevert(IGhoRouter.InvalidAmount.selector);
        router.previewSwapFromsGHO(address(gsm), address(underlying), 0);
    }

    function test_reverts_preview_direct_from_sgho_zero_amount() public {
        vm.expectRevert(IGhoRouter.InvalidAmount.selector);
        router.previewSwapFromsGHO(0);
    }

    function test_reverts_direct_swap_to_sgho_zero_amount() public {
        vm.startPrank(USER);
        vm.expectRevert(IGhoRouter.InvalidAmount.selector);
        router.swapTosGHO(0, 0);
        vm.stopPrank();
    }

    function test_swap_from_gho_to_token_with_recipient_overload() public {
        uint256 ghoAmount = 100e18;
        _mintAndApproveGho(ghoAmount);

        uint256 recipientBefore = underlying.balanceOf(RECIPIENT);
        vm.prank(USER);
        uint256 output = router.swapFromGHO(address(gsm), address(underlying), ghoAmount, 0, RECIPIENT);

        assertEq(underlying.balanceOf(RECIPIENT) - recipientBefore, output);
        assertEq(output, ghoAmount);
    }

    function test_swap_to_sgho_with_recipient_overload() public {
        uint256 amount = 250e18;
        _mintAndApproveUnderlying(amount);

        uint256 recipientBefore = sgho.balanceOf(RECIPIENT);
        vm.prank(USER);
        uint256 shares = router.swapTosGHO(address(gsm), address(underlying), amount, 0, RECIPIENT);

        assertEq(sgho.balanceOf(RECIPIENT) - recipientBefore, shares);
        assertEq(shares, amount);
    }

    function test_swap_from_sgho_with_recipient_overload() public {
        uint256 sghoAmount = 100e18;
        _mintSghoAndApprove(sghoAmount);

        uint256 recipientBefore = underlying.balanceOf(RECIPIENT);
        vm.prank(USER);
        uint256 output = router.swapFromsGHO(address(gsm), sghoAmount, 0, RECIPIENT);

        assertEq(underlying.balanceOf(RECIPIENT) - recipientBefore, output);
        assertEq(output, sghoAmount);
    }

    function test_swap_from_sgho_to_token_with_recipient_overload() public {
        uint256 sghoAmount = 75e18;
        _mintSghoAndApprove(sghoAmount);

        uint256 recipientBefore = underlying.balanceOf(RECIPIENT);
        vm.prank(USER);
        uint256 output = router.swapFromsGHO(address(gsm), address(underlying), sghoAmount, 0, RECIPIENT);

        assertEq(underlying.balanceOf(RECIPIENT) - recipientBefore, output);
        assertEq(output, sghoAmount);
    }

    function test_swap_to_gho_refunds_unsold_underlying_when_gsm_partially_fills() public {
        gsm.setSellFillBps(5_000);

        uint256 amount = 1_000e18;
        _mintAndApproveUnderlying(amount);

        vm.prank(USER);
        uint256 ghoReceived = router.swapToGHO(address(gsm), address(underlying), amount, 0);

        assertEq(ghoReceived, amount / 2);
        assertEq(gho.balanceOf(USER), amount / 2);
        assertEq(underlying.balanceOf(USER), amount / 2);
    }

    function test_reverts_direct_swap_to_sgho_when_min_out_too_high() public {
        uint256 ghoAmount = 10e18;
        _mintAndApproveGho(ghoAmount);

        vm.startPrank(USER);
        vm.expectRevert(IGhoRouter.SlippageExceeded.selector);
        router.swapTosGHO(ghoAmount, ghoAmount + 1);
        vm.stopPrank();
    }

    function test_reverts_direct_swap_from_sgho_when_min_out_too_high() public {
        uint256 sghoAmount = 10e18;
        _mintSghoAndApprove(sghoAmount);

        vm.startPrank(USER);
        vm.expectRevert(IGhoRouter.SlippageExceeded.selector);
        router.swapFromsGHO(sghoAmount, sghoAmount + 1);
        vm.stopPrank();
    }
}

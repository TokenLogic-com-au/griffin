// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStaticAToken} from "./interfaces/IStaticAToken.sol";
import {IGSM} from "./interfaces/IGSM.sol";
import {Addresses} from "./Addresses.sol";

/**
 * @title GHORouter
 * @notice Router contract to swap USDC/USDT to GHO in a single transaction
 * @dev This contract never stores user funds and uses exact approvals only
 * @dev Uses SafeERC20 to handle non-standard tokens like USDT
 */
contract GHORouter {
    using SafeERC20 for IERC20;

    error InvalidToken();
    error InvalidAmount();
    error SlippageExceeded();

    event SwapToGHO(address indexed user, address indexed inputToken, uint256 inputAmount, uint256 ghoAmount);

    event SwapFromGHO(address indexed user, address indexed outputToken, uint256 ghoAmount, uint256 outputAmount);

    /**
     * @notice Swap USDC or USDT to GHO
     * @param token Input token (USDC or USDT)
     * @param amount Amount of input token
     * @param minGHOAmount Minimum GHO to receive (slippage protection)
     * @return ghoAmount Amount of GHO received
     */
    function swapToGHO(address token, uint256 amount, uint256 minGHOAmount) external returns (uint256 ghoAmount) {
        if (amount == 0) revert InvalidAmount();
        if (token != Addresses.USDC && token != Addresses.USDT) revert InvalidToken();

        address gsmAddress = token == Addresses.USDC ? Addresses.GSM_USDC : Addresses.GSM_USDT;
        address stataToken = token == Addresses.USDC ? Addresses.STATA_USDC : Addresses.STATA_USDT;

        // Transfer tokens from user
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Step 1: Deposit underlying asset to stataToken (ERC-4626 vault)
        // The stataToken handles Aave supply internally
        IERC20(token).forceApprove(stataToken, amount);
        uint256 stataAmount = IStaticAToken(stataToken).deposit(amount, address(this));

        // Step 2: Swap stataToken for GHO via GSM
        IERC20(stataToken).forceApprove(gsmAddress, stataAmount);
        (, ghoAmount) = IGSM(gsmAddress).sellAsset(stataAmount, address(this));

        // Slippage check
        if (ghoAmount < minGHOAmount) revert SlippageExceeded();

        // Transfer GHO to user
        IERC20(Addresses.GHO).safeTransfer(msg.sender, ghoAmount);

        emit SwapToGHO(msg.sender, token, amount, ghoAmount);
    }

    /**
     * @notice Swap GHO back to USDC or USDT
     * @param token Output token (USDC or USDT)
     * @param ghoAmount Amount of GHO to swap
     * @param minOutputAmount Minimum output token to receive
     * @return outputAmount Amount of output token received
     */
    function swapFromGHO(address token, uint256 ghoAmount, uint256 minOutputAmount)
        external
        returns (uint256 outputAmount)
    {
        if (ghoAmount == 0) revert InvalidAmount();
        if (token != Addresses.USDC && token != Addresses.USDT) revert InvalidToken();

        address gsmAddress = token == Addresses.USDC ? Addresses.GSM_USDC : Addresses.GSM_USDT;
        address stataToken = token == Addresses.USDC ? Addresses.STATA_USDC : Addresses.STATA_USDT;

        // Transfer GHO from user
        IERC20(Addresses.GHO).safeTransferFrom(msg.sender, address(this), ghoAmount);

        // Step 1: Swap GHO for stataToken via GSM
        IERC20(Addresses.GHO).forceApprove(gsmAddress, ghoAmount);
        (uint256 stataAmount,) = IGSM(gsmAddress).buyAsset(0, address(this));

        // Step 2: Redeem stataToken for underlying asset (ERC-4626 vault)
        // The stataToken handles Aave withdrawal internally
        outputAmount = IStaticAToken(stataToken).redeem(stataAmount, address(this), address(this));

        // Slippage check
        if (outputAmount < minOutputAmount) revert SlippageExceeded();

        // Transfer output token to user
        IERC20(token).safeTransfer(msg.sender, outputAmount);

        emit SwapFromGHO(msg.sender, token, ghoAmount, outputAmount);
    }

    /**
     * @notice Preview how much GHO will be received for a given amount
     * @param token Input token
     * @param amount Input amount (stataToken amount)
     * @return ghoAmount Expected GHO amount (after fees)
     * @return fee Fee amount
     */
    function previewSwapToGHO(address token, uint256 amount) external view returns (uint256 ghoAmount, uint256 fee) {
        if (token != Addresses.USDC && token != Addresses.USDT) revert InvalidToken();

        address gsmAddress = token == Addresses.USDC ? Addresses.GSM_USDC : Addresses.GSM_USDT;

        // Get preview from GSM - this is a simplified preview
        // Actual amount may vary slightly due to interest accrual in Aave
        (, ghoAmount,, fee) = IGSM(gsmAddress).getGhoAmountForSellAsset(amount);
    }

    /**
     * @notice Preview how much output token will be received for a given GHO amount
     * @param token Output token (USDC or USDT)
     * @param ghoAmount GHO amount to swap
     * @return assetAmount Expected output token amount (stataToken, after fees)
     * @return fee Fee amount
     */
    function previewSwapFromGHO(address token, uint256 ghoAmount)
        external
        view
        returns (uint256 assetAmount, uint256 fee)
    {
        if (token != Addresses.USDC && token != Addresses.USDT) revert InvalidToken();

        address gsmAddress = token == Addresses.USDC ? Addresses.GSM_USDC : Addresses.GSM_USDT;

        // Get preview from GSM
        (, assetAmount,, fee) = IGSM(gsmAddress).getAssetAmountForBuyAsset(ghoAmount);
    }
}

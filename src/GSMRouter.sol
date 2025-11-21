// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStaticAToken} from "./interfaces/IStaticAToken.sol";
import {IGSM} from "./interfaces/IGSM.sol";

/**
 * @title GSMRouter
 * @notice Router contract to swap USDC/USDT to GHO in a single transaction
 * @dev This contract never stores user funds and uses exact approvals only
 * @dev Uses SafeERC20 to handle non-standard tokens like USDT
 */
contract GSMRouter is Ownable {
    using SafeERC20 for IERC20;

    // Token Constants
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    // Static aTokens Constants
    address public constant STATA_USDC = 0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E;
    address public constant STATA_USDT = 0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8;

    // GSM State Variables
    address public gsmUSDC;
    address public gsmUSDT;

    error InvalidToken();
    error InvalidAmount();
    error SlippageExceeded();
    error ZeroAddress();

    event SwapToGHO(address indexed user, address indexed inputToken, uint256 inputAmount, uint256 ghoAmount);
    event SwapFromGHO(address indexed user, address indexed outputToken, uint256 ghoAmount, uint256 outputAmount);
    event GsmUSDCUpdated(address indexed newGsm);
    event GsmUSDTUpdated(address indexed newGsm);

    constructor(address _owner, address _gsmUSDC, address _gsmUSDT) Ownable(_owner) {
        if (_gsmUSDC == address(0) || _gsmUSDT == address(0)) revert ZeroAddress();
        gsmUSDC = _gsmUSDC;
        gsmUSDT = _gsmUSDT;
    }

    /**
     * @notice Updates the GSM address for USDC
     * @param _gsmUSDC New GSM USDC address
     */
    function setGsmUSDC(address _gsmUSDC) external onlyOwner {
        if (_gsmUSDC == address(0)) revert ZeroAddress();
        gsmUSDC = _gsmUSDC;
        emit GsmUSDCUpdated(_gsmUSDC);
    }

    /**
     * @notice Updates the GSM address for USDT
     * @param _gsmUSDT New GSM USDT address
     */
    function setGsmUSDT(address _gsmUSDT) external onlyOwner {
        if (_gsmUSDT == address(0)) revert ZeroAddress();
        gsmUSDT = _gsmUSDT;
        emit GsmUSDTUpdated(_gsmUSDT);
    }

    /**
     * @notice Swap USDC or USDT to GHO
     * @param token Input token (USDC or USDT)
     * @param amount Amount of input token
     * @param minGHOAmount Minimum GHO to receive (slippage protection)
     * @return ghoAmount Amount of GHO received
     */
    function swapToGHO(address token, uint256 amount, uint256 minGHOAmount) external returns (uint256) {
        if (amount == 0) revert InvalidAmount();
        if (token != USDC && token != USDT) revert InvalidToken();

        address gsmAddress = token == USDC ? gsmUSDC : gsmUSDT;
        address stataToken = token == USDC ? STATA_USDC : STATA_USDT;

        // Transfer tokens from user
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Step 1: Deposit underlying asset to stataToken (ERC-4626 vault)
        // The stataToken handles Aave supply internally
        IERC20(token).forceApprove(stataToken, amount);
        uint256 stataAmount = IStaticAToken(stataToken).deposit(amount, address(this));

        // Step 2: Swap stataToken for GHO via GSM
        IERC20(stataToken).forceApprove(gsmAddress, stataAmount);
        (, uint256 ghoAmount) = IGSM(gsmAddress).sellAsset(stataAmount, address(this));

        // Slippage check
        if (ghoAmount < minGHOAmount) revert SlippageExceeded();

        // Transfer GHO to user
        IERC20(GHO).safeTransfer(msg.sender, ghoAmount);

        emit SwapToGHO(msg.sender, token, amount, ghoAmount);

        return ghoAmount;
    }

    /**
     * @notice Swap GHO back to USDC or USDT
     * @param token Output token (USDC or USDT)
     * @param ghoAmount Amount of GHO to swap
     * @param minOutputAmount Minimum output token to receive
     * @return outputAmount Amount of output token received
     */
    function swapFromGHO(address token, uint256 ghoAmount, uint256 minOutputAmount) external returns (uint256) {
        if (ghoAmount == 0) revert InvalidAmount();
        if (token != USDC && token != USDT) revert InvalidToken();

        address gsmAddress = token == USDC ? gsmUSDC : gsmUSDT;
        address stataToken = token == USDC ? STATA_USDC : STATA_USDT;

        // Transfer GHO from user
        IERC20(GHO).safeTransferFrom(msg.sender, address(this), ghoAmount);

        // Step 1: Swap GHO for stataToken via GSM
        IERC20(GHO).forceApprove(gsmAddress, ghoAmount);
        (uint256 stataAmount,) = IGSM(gsmAddress).buyAsset(0, address(this));

        // Step 2: Redeem stataToken for underlying asset (ERC-4626 vault)
        // The stataToken handles Aave withdrawal internally
        uint256 outputAmount = IStaticAToken(stataToken).redeem(stataAmount, address(this), address(this));

        // Slippage check
        if (outputAmount < minOutputAmount) revert SlippageExceeded();

        // Transfer output token to user
        IERC20(token).safeTransfer(msg.sender, outputAmount);

        emit SwapFromGHO(msg.sender, token, ghoAmount, outputAmount);

        return outputAmount;
    }

    /**
     * @notice Preview how much GHO will be received for a given amount
     * @param token Input token
     * @param amount Input amount (stataToken amount)
     * @return ghoAmount Expected GHO amount (after fees)
     * @return fee Fee amount
     */
    function previewSwapToGHO(address token, uint256 amount) external view returns (uint256, uint256) {
        if (token != USDC && token != USDT) revert InvalidToken();

        address gsmAddress = token == USDC ? gsmUSDC : gsmUSDT;

        // Get preview from GSM - this is a simplified preview
        // Actual amount may vary slightly due to interest accrual in Aave
        (, uint256 ghoAmount,, uint256 fee) = IGSM(gsmAddress).getGhoAmountForSellAsset(amount);
        return (ghoAmount, fee);
    }

    /**
     * @notice Preview how much output token will be received for a given GHO amount
     * @param token Output token (USDC or USDT)
     * @param ghoAmount GHO amount to swap
     * @return assetAmount Expected output token amount (stataToken, after fees)
     * @return fee Fee amount
     */
    function previewSwapFromGHO(address token, uint256 ghoAmount) external view returns (uint256, uint256) {
        if (token != USDC && token != USDT) revert InvalidToken();

        address gsmAddress = token == USDC ? gsmUSDC : gsmUSDT;

        // Get preview from GSM
        (, uint256 assetAmount,, uint256 fee) = IGSM(gsmAddress).getAssetAmountForBuyAsset(ghoAmount);
        return (assetAmount, fee);
    }
}

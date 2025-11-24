// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStaticAToken} from "./interfaces/IStaticAToken.sol";
import {IGSM} from "./interfaces/IGSM.sol";
import {IGSMRouter} from "./interfaces/IGSMRouter.sol";

/**
 * @title GSMRouter
 * @notice Router contract to swap USDC/USDT to GHO in a single transaction
 * @dev This contract never stores user funds and uses exact approvals only
 * @dev Uses SafeERC20 to handle non-standard tokens like USDT
 */
contract GSMRouter is Ownable, IGSMRouter {
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

    /// @dev Constructor to initialize the contract with owner and GSM addresses
    constructor(address _owner, address _gsmUSDC, address _gsmUSDT) Ownable(_owner) {
        if (_gsmUSDC == address(0) || _gsmUSDT == address(0)) revert ZeroAddress();
        gsmUSDC = _gsmUSDC;
        gsmUSDT = _gsmUSDT;
    }

    /// @inheritdoc IGSMRouter
    function setGsmUSDC(address _gsmUSDC) external onlyOwner {
        if (_gsmUSDC == address(0)) revert ZeroAddress();
        gsmUSDC = _gsmUSDC;
        emit GsmUSDCUpdated(_gsmUSDC);
    }

    /// @inheritdoc IGSMRouter
    function setGsmUSDT(address _gsmUSDT) external onlyOwner {
        if (_gsmUSDT == address(0)) revert ZeroAddress();
        gsmUSDT = _gsmUSDT;
        emit GsmUSDTUpdated(_gsmUSDT);
    }

    /// @inheritdoc IGSMRouter
    function swapToGHO(address token, uint256 amount, uint256 minGHOAmount) external returns (uint256) {
        if (amount < 1) revert InvalidAmount();
        if (token != USDC && token != USDT) revert InvalidToken();

        (address gsmAddress, address stataToken) = token == USDC ? (gsmUSDC, STATA_USDC) : (gsmUSDT, STATA_USDT);

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

    /// @inheritdoc IGSMRouter
    function swapFromGHO(address token, uint256 ghoAmount, uint256 minOutputAmount) external returns (uint256) {
        if (ghoAmount < 1) revert InvalidAmount();
        if (token != USDC && token != USDT) revert InvalidToken();

        (address gsmAddress, address stataToken) = token == USDC ? (gsmUSDC, STATA_USDC) : (gsmUSDT, STATA_USDT);

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

    /// @inheritdoc IGSMRouter
    function previewSwapToGHO(address token, uint256 amount) external view returns (uint256, uint256) {
        if (token != USDC && token != USDT) revert InvalidToken();

        address gsmAddress = token == USDC ? gsmUSDC : gsmUSDT;

        // Get preview from GSM - this is a simplified preview
        // Actual amount may vary slightly due to interest accrual in Aave
        (, uint256 ghoAmount,, uint256 fee) = IGSM(gsmAddress).getGhoAmountForSellAsset(amount);
        return (ghoAmount, fee);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapFromGHO(address token, uint256 ghoAmount) external view returns (uint256, uint256) {
        if (token != USDC && token != USDT) revert InvalidToken();

        address gsmAddress = token == USDC ? gsmUSDC : gsmUSDT;

        // Get preview from GSM
        (, uint256 assetAmount,, uint256 fee) = IGSM(gsmAddress).getAssetAmountForBuyAsset(ghoAmount);
        return (assetAmount, fee);
    }
}

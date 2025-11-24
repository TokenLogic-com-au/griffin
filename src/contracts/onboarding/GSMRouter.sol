// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStaticAToken} from "./interfaces/IStaticAToken.sol";
import {IGSM} from "src/interfaces/IGSM.sol";
import {IGSMRouter} from "src/interfaces/onboarding/IGSMRouter.sol";

/**
 * @title GSMRouter
 * @notice Router contract to swap USDC/USDT to GHO in a single transaction
 * @dev This contract never stores user funds and uses exact approvals only
 * @dev Uses SafeERC20 to handle non-standard tokens like USDT
 */
contract GSMRouter is Ownable, IGSMRouter {
    using SafeERC20 for IERC20;

    /// @inheritdoc IGSMRouter
    address public immutable USDC;

    /// @inheritdoc IGSMRouter
    address public immutable USDT;

    /// @inheritdoc IGSMRouter
    address public immutable GHO;

    /// @inheritdoc IGSMRouter
    address public immutable STATA_USDC;

    /// @inheritdoc IGSMRouter
    address public immutable STATA_USDT

    /// @inheritdoc IGSMRouter
    address public _gsmUSDC;

    /// @inheritdoc IGSMRouter
    address public _gsmUSDT;

    /// @dev Constructor to initialize the contract with owner and GSM addresses
    constructor(
        address owner,
        address gsmUSDC,
        address gsmUSDT,
        address usdc,
        address usdt,
        address gho,
        address stataUsdc,
        address stataUsdt
    ) Ownable(_owner) {
        require(gsmUSDC != address(0), ZeroAddress());
        require(gsmUSDT != address(0), ZeroAddress());
        require(usdc != address(0), ZeroAddress());
        require(usdt != address(0), ZeroAddress());
        require(gho != address(0), ZeroAddress());
        require(stataUsdc != address(0), ZeroAddress());
        require(stataUsdt != address(0), ZeroAddress());

        gsmUSDC = _gsmUSDC;
        gsmUSDT = _gsmUSDT;
        USDC = usdc;
        USDT = usdt;
        GHO = gho;
        STATA_USDC = stataUsdc;
        STATA_USDT = stataUsdt;
    }

    /// @inheritdoc IGSMRouter
    function swapToGHO(
        address token,
        uint256 amount,
        uint256 minGHOAmount
    ) external returns (uint256) {
        require(amount > 0, InvalidAmount());
        require(token == USDC || token == USDT, InvalidToken());

        (address gsmAddress, address stataToken) = token == USDC
            ? (gsmUSDC, STATA_USDC)
            : (gsmUSDT, STATA_USDT);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Step 1: Deposit underlying asset to stataToken
        IERC20(token).forceApprove(stataToken, amount);
        uint256 stataAmount = IStaticAToken(stataToken).deposit(
            amount,
            address(this)
        );

        // Step 2: Swap stataToken for GHO via GSM
        IERC20(stataToken).forceApprove(gsmAddress, stataAmount);
        (, uint256 ghoAmount) = IGSM(gsmAddress).sellAsset(
            stataAmount,
            address(this)
        );

        if (ghoAmount < minGHOAmount) revert SlippageExceeded();

        IERC20(GHO).safeTransfer(msg.sender, ghoAmount);

        emit SwapToGHO(msg.sender, token, amount, ghoAmount);

        return ghoAmount;
    }

    /// @inheritdoc IGSMRouter
    function swapFromGHO(
        address token,
        uint256 ghoAmount,
        uint256 minOutputAmount
    ) external returns (uint256) {
        require(amount > 0, InvalidAmount());
        require(token == USDC || token == USDT, InvalidToken());

        (address gsmAddress, address stataToken) = token == USDC
            ? (gsmUSDC, STATA_USDC)
            : (gsmUSDT, STATA_USDT);

        IERC20(GHO).safeTransferFrom(msg.sender, address(this), ghoAmount);

        // Step 1: Calculate exact stataToken amount to buy with GHO
        (uint256 stataAmountToBuy, , , ) = IGSM(gsmAddress)
            .getAssetAmountForBuyAsset(ghoAmount);

        // Step 2: Swap GHO for stataToken via GSM
        IERC20(GHO).forceApprove(gsmAddress, ghoAmount);
        (uint256 stataAmount, ) = IGSM(gsmAddress).buyAsset(
            stataAmountToBuy,
            address(this)
        );

        // Step 3: Redeem stataToken for underlying asset
        uint256 outputAmount = IStaticAToken(stataToken).redeem(
            stataAmount,
            address(this),
            address(this)
        );

        if (outputAmount < minOutputAmount) revert SlippageExceeded();

        IERC20(token).safeTransfer(msg.sender, outputAmount);

        emit SwapFromGHO(msg.sender, token, ghoAmount, outputAmount);

        return outputAmount;
    }

    /// @inheritdoc IGSMRouter
    function setGsmUSDC(address gsmUSDC) external onlyOwner {
        require(gsmUSDC != address(0), ZeroAddress());
        _gsmUSDC = gsmUSDC;
        emit GsmUSDCUpdated(gsmUSDC);
    }

    /// @inheritdoc IGSMRouter
    function setGsmUSDT(address gsmUSDT) external onlyOwner {
        require(gsmUSDT != address(0), ZeroAddress());
        _gsmUSDT = gsmUSDT;
        emit GsmUSDTUpdated(gsmUSDT);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapToGHO(
        address token,
        uint256 amount
    ) external view returns (uint256, uint256) {
        require(token == USDC || token == USDT, InvalidToken());

        (address gsmAddress, address stataToken) = token == USDC
            ? (gsmUSDC, STATA_USDC)
            : (gsmUSDT, STATA_USDT);

        uint256 sharesAmount = IStaticAToken(stataToken).previewDeposit(amount);

        // This is a simplified preview:
        // Actual amount may vary slightly due to interest accrual in Aave
        (, uint256 ghoAmount, , uint256 fee) = IGSM(gsmAddress)
            .getGhoAmountForSellAsset(sharesAmount);
        return (ghoAmount, fee);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapFromGHO(
        address token,
        uint256 ghoAmount
    ) external view returns (uint256, uint256) {
        require(token == USDC || token == USDT, InvalidToken());

        (address gsmAddress, address stataToken) = token == USDC
            ? (gsmUSDC, STATA_USDC)
            : (gsmUSDT, STATA_USDT);

        (uint256 assetAmount, , , uint256 fee) = IGSM(gsmAddress)
            .getAssetAmountForBuyAsset(ghoAmount);

        uint256 outputAmount = IStaticAToken(stataToken).previewRedeem(
            assetAmount
        );

        return (outputAmount, fee);
    }
}

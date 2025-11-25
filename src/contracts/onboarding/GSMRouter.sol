// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IStaticAToken} from "src/interfaces/IStaticAToken.sol";
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
    address public immutable GHO;

    /// @inheritdoc IGSMRouter
    mapping(address token => mapping(address stataToken => address gsm))
        public tokenToGsm;

    /**
     * @dev Constructor to initialize the contract with owner and GSM addresses
     * @param gho Address of the GHO token on the deployed network
     */

    constructor(address owner, address gho) Ownable(owner) {
        require(gho != address(0), ZeroAddress());

        GHO = gho;
    }

    /// @inheritdoc IGSMRouter
    function swapToGHO(
        address token,
        uint256 amount,
        uint256 minGHOAmount
    ) external returns (uint256) {
        require(amount > 0, InvalidAmount());

        address stataToken = tokenToGsm[token];
        address gsm = tokenToGsm[token][stataToken];

        require(stataToken != address(0), InvalidToken());
        require(gsm != address(0), InvalidGsm());

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Step 1: Deposit underlying asset to stataToken
        IERC20(token).forceApprove(stataToken, amount);
        uint256 stataAmount = IStaticAToken(stataToken).deposit(
            amount,
            address(this)
        );

        // Step 2: Swap stataToken for GHO via GSM
        IERC20(stataToken).forceApprove(gsm, stataAmount);
        (, uint256 ghoAmount) = IGSM(gsm).sellAsset(stataAmount, address(this));

        require(minGHOAmount >= ghoAmount, SlippageExceeded());

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
        require(ghoAmount > 0, InvalidAmount());

        address stataToken = tokenToGsm[token];
        address gsm = tokenToGsm[token][stataToken];

        require(stataToken != address(0), InvalidToken());
        require(gsm != address(0), InvalidGsm());

        IERC20(GHO).safeTransferFrom(msg.sender, address(this), ghoAmount);

        // Step 1: Calculate exact stataToken amount to buy with GHO
        (uint256 stataAmountToBuy, , , ) = IGSM(gsm).getAssetAmountForBuyAsset(
            ghoAmount
        );

        // Step 2: Swap GHO for stataToken via GSM
        IERC20(GHO).forceApprove(gsm, ghoAmount);
        (uint256 stataAmount, ) = IGSM(gsm).buyAsset(
            stataAmountToBuy,
            address(this)
        );

        // Step 3: Redeem stataToken for underlying asset
        uint256 outputAmount = IStaticAToken(stataToken).redeem(
            stataAmount,
            msg.sender,
            address(this)
        );

        require(minOutputAmount >= outputAmount, SlippageExceeded());

        emit SwapFromGHO(msg.sender, token, ghoAmount, outputAmount);

        return outputAmount;
    }

    /// @inheritdoc IGSMRouter
    function setTokenToGsmMapping(
        address token,
        address stataToken,
        address gsm
    ) external onlyOwner {
        require(token != address(0), ZeroAddress());
        require(stataToken != address(0), ZeroAddress());
        require(gsm != address(0), ZeroAddress());

        tokenToGsm[token][stataToken][gsm];

        emit TokenToGsmMapped(token, stataToken, gsm);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapToGHO(
        address token,
        uint256 amount
    ) external view returns (uint256, uint256) {
        require(amount > 0, InvalidAmount());

        address stataToken = tokenToGsm[token];
        address gsm = tokenToGsm[token][stataToken];

        require(stataToken != address(0), InvalidToken());
        require(gsm != address(0), InvalidGsm());

        uint256 sharesAmount = IStaticAToken(stataToken).previewDeposit(amount);

        // This is a simplified preview:
        // Actual amount may vary slightly due to interest accrual in Aave
        (, uint256 ghoAmount, , uint256 fee) = IGSM(gsm)
            .getGhoAmountForSellAsset(sharesAmount);
        return (ghoAmount, fee);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapFromGHO(
        address token,
        uint256 ghoAmount
    ) external view returns (uint256, uint256) {
        require(ghoAmount > 0, InvalidAmount());

        address stataToken = tokenToGsm[token];
        address gsm = tokenToGsm[token][stataToken];

        require(stataToken != address(0), InvalidToken());
        require(gsm != address(0), InvalidGsm());

        (uint256 assetAmount, , , uint256 fee) = IGSM(gsm)
            .getAssetAmountForBuyAsset(ghoAmount);

        uint256 outputAmount = IStaticAToken(stataToken).previewRedeem(
            assetAmount
        );

        return (outputAmount, fee);
    }
}

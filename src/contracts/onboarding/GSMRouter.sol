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
    mapping(address token => TokenConfig) public tokenConfig;

    /**
     * @dev Constructor to initialize the contract
     * @param owner Address of the contract owner
     * @param gho Address of the GHO token on the deployed network
     */
    constructor(address owner, address gho) Ownable(owner) {
        require(gho != address(0), ZeroAddress());

        GHO = gho;
    }

    /// @inheritdoc IGSMRouter
    function swapToGHO(address token, uint256 amount, uint256 minGHOAmount) external returns (uint256) {
        require(amount > 0, InvalidAmount());

        TokenConfig memory config = tokenConfig[token];
        require(config.stataToken != address(0), InvalidToken());
        require(config.gsm != address(0), InvalidGsm());

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Step 1: Deposit underlying asset to stataToken
        IERC20(token).forceApprove(config.stataToken, amount);
        uint256 stataAmount = IStaticAToken(config.stataToken).deposit(amount, address(this));

        // Step 2: Swap stataToken for GHO via GSM
        IERC20(config.stataToken).forceApprove(config.gsm, stataAmount);
        (uint256 assetSold, uint256 ghoAmount) = IGSM(config.gsm).sellAsset(stataAmount, address(this));

        require(ghoAmount >= minGHOAmount, SlippageExceeded());

        // If GSM used less than the approved stataAmount, redeem the remainder back to the user
        if (assetSold < stataAmount) {
            uint256 leftoverShares = stataAmount - assetSold;
            IStaticAToken(config.stataToken).redeem(leftoverShares, msg.sender, address(this));
        }

        IERC20(GHO).safeTransfer(msg.sender, ghoAmount);

        emit SwapToGHO(msg.sender, token, assetSold, ghoAmount);

        return ghoAmount;
    }

    /// @inheritdoc IGSMRouter
    function swapFromGHO(address token, uint256 ghoAmount, uint256 minOutputAmount) external returns (uint256) {
        require(ghoAmount > 0, InvalidAmount());

        TokenConfig memory config = tokenConfig[token];
        require(config.stataToken != address(0), InvalidToken());
        require(config.gsm != address(0), InvalidGsm());

        IERC20(GHO).safeTransferFrom(msg.sender, address(this), ghoAmount);

        // Step 1: Calculate exact stataToken amount to buy with GHO
        (uint256 stataAmountToBuy,,,) = IGSM(config.gsm).getAssetAmountForBuyAsset(ghoAmount);

        // Step 2: Swap GHO for stataToken via GSM
        IERC20(GHO).forceApprove(config.gsm, ghoAmount);
        (uint256 stataAmount, uint256 ghoBurned) = IGSM(config.gsm).buyAsset(stataAmountToBuy, address(this));

        // Refund any unspent GHO
        if (ghoBurned < ghoAmount) {
            IERC20(GHO).safeTransfer(msg.sender, ghoAmount - ghoBurned);
        }

        // Step 3: Redeem stataToken for underlying asset
        uint256 outputAmount = IStaticAToken(config.stataToken).redeem(stataAmount, msg.sender, address(this));

        require(outputAmount >= minOutputAmount, SlippageExceeded());

        emit SwapFromGHO(msg.sender, token, ghoBurned, outputAmount);

        return outputAmount;
    }

    /// @inheritdoc IGSMRouter
    function setTokenConfig(address token, address stataToken, address gsm) external onlyOwner {
        require(token != address(0), ZeroAddress());
        require(stataToken != address(0), ZeroAddress());
        require(gsm != address(0), ZeroAddress());

        tokenConfig[token] = TokenConfig(stataToken, gsm);

        emit TokenConfigSet(token, stataToken, gsm);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapToGHO(address token, uint256 amount) external view returns (uint256, uint256) {
        require(amount > 0, InvalidAmount());

        TokenConfig memory config = tokenConfig[token];
        require(config.stataToken != address(0), InvalidToken());
        require(config.gsm != address(0), InvalidGsm());

        uint256 sharesAmount = IStaticAToken(config.stataToken).previewDeposit(amount);

        // This is a simplified preview:
        // Actual amount may vary slightly due to interest accrual in Aave
        (, uint256 ghoAmount,, uint256 fee) = IGSM(config.gsm).getGhoAmountForSellAsset(sharesAmount);
        return (ghoAmount, fee);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapFromGHO(address token, uint256 ghoAmount) external view returns (uint256, uint256) {
        require(ghoAmount > 0, InvalidAmount());

        TokenConfig memory config = tokenConfig[token];
        require(config.stataToken != address(0), InvalidToken());
        require(config.gsm != address(0), InvalidGsm());

        (uint256 assetAmount,,, uint256 fee) = IGSM(config.gsm).getAssetAmountForBuyAsset(ghoAmount);

        uint256 outputAmount = IStaticAToken(config.stataToken).previewRedeem(assetAmount);

        return (outputAmount, fee);
    }
}

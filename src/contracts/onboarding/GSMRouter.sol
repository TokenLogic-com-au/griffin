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

    /**
     * @dev Constructor to initialize the contract
     * @param owner Address of the contract owner
     * @param gho Address of the GHO token on the deployed network
     */
    constructor(address owner, address gho) Ownable(owner) {
        require(gho != address(0), ZeroAddress());

        GHO = gho;
    }

    function _getTokensFromGsm(address gsm) internal view returns (address token, address stataToken) {
        require(gsm != address(0), ZeroAddress());
        require(gsm.code.length != 0, InvalidGsm());

        address ghoToken;
        try IGSM(gsm).GHO_TOKEN() returns (address ghoFromGsm) {
            ghoToken = ghoFromGsm;
        } catch {
            revert InvalidGsm();
        }
        require(ghoToken == GHO, InvalidGsm());

        // Get the stataToken from the GSM contract as GSMs hold stata as underlying asset
        try IGSM(gsm).UNDERLYING_ASSET() returns (address stataFromGsm) {
            stataToken = stataFromGsm;
        } catch {
            revert InvalidGsm();
        }
        require(stataToken != address(0), InvalidGsm());

        // Get the plain token (USDC/USDT) from the stataToken as stataTokens hold these in a vault
        try IStaticAToken(stataToken).asset() returns (address underlyingToken) {
            token = underlyingToken;
        } catch {
            revert InvalidToken();
        }
        require(token != address(0), InvalidToken());
    }

    /// @inheritdoc IGSMRouter
    function swapToGHO(address gsm, uint256 amount, uint256 minGHOAmount) external returns (uint256) {
        require(amount > 0, InvalidAmount());

        (address token, address stataToken) = _getTokensFromGsm(gsm);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Step 1: Deposit underlying asset to stataToken
        IERC20(token).forceApprove(stataToken, amount);
        uint256 stataAmount = IStaticAToken(stataToken).deposit(amount, address(this));

        // Step 2: Swap stataToken for GHO via GSM
        IERC20(stataToken).forceApprove(gsm, stataAmount);
        (uint256 assetSold, uint256 ghoAmount) = IGSM(gsm).sellAsset(stataAmount, address(this));

        // Clear residual allowance
        IERC20(stataToken).forceApprove(gsm, 0);

        // Handle stataToken dust if GSM didn't consume full amount
        uint256 dustRedeemed;
        if (assetSold < stataAmount) {
            uint256 dust = stataAmount - assetSold;
            dustRedeemed = IStaticAToken(stataToken).redeem(dust, msg.sender, address(this));
            emit DustReturned(msg.sender, token, dustRedeemed);
        }

        require(ghoAmount >= minGHOAmount, SlippageExceeded());

        IERC20(GHO).safeTransfer(msg.sender, ghoAmount);

        emit SwapToGHO(msg.sender, token, amount - dustRedeemed, ghoAmount);

        return ghoAmount;
    }

    /// @inheritdoc IGSMRouter
    function swapFromGHO(address gsm, uint256 ghoAmount, uint256 minOutputAmount) external returns (uint256) {
        require(ghoAmount > 0, InvalidAmount());

        (address token, address stataToken) = _getTokensFromGsm(gsm);

        IERC20(GHO).safeTransferFrom(msg.sender, address(this), ghoAmount);

        // Step 1: Calculate exact stataToken amount to buy with GHO
        (uint256 stataAmountToBuy,,,) = IGSM(gsm).getAssetAmountForBuyAsset(ghoAmount);

        // Step 2: Swap GHO for stataToken via GSM
        IERC20(GHO).forceApprove(gsm, ghoAmount);
        (uint256 stataAmount, uint256 ghoBurned) = IGSM(gsm).buyAsset(stataAmountToBuy, address(this));

        // Clear residual allowance
        IERC20(GHO).forceApprove(gsm, 0);

        // Handle GHO dust if GSM didn't burn full amount
        if (ghoBurned < ghoAmount) {
            uint256 ghoDust = ghoAmount - ghoBurned;
            IERC20(GHO).safeTransfer(msg.sender, ghoDust);
            emit DustReturned(msg.sender, GHO, ghoDust);
        }

        // Step 3: Redeem stataToken for underlying asset
        uint256 outputAmount = IStaticAToken(stataToken).redeem(stataAmount, msg.sender, address(this));

        require(outputAmount >= minOutputAmount, SlippageExceeded());

        emit SwapFromGHO(msg.sender, token, ghoBurned, outputAmount);

        return outputAmount;
    }

    /// @inheritdoc IGSMRouter
    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapToGHO(address gsm, uint256 amount) external view returns (uint256, uint256) {
        require(amount > 0, InvalidAmount());

        (, address stataToken) = _getTokensFromGsm(gsm);

        uint256 sharesAmount = IStaticAToken(stataToken).previewDeposit(amount);

        // This is a simplified preview:
        // Actual amount may vary slightly due to interest accrual in Aave
        (, uint256 ghoAmount,, uint256 fee) = IGSM(gsm).getGhoAmountForSellAsset(sharesAmount);
        return (ghoAmount, fee);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapFromGHO(address gsm, uint256 ghoAmount) external view returns (uint256, uint256) {
        require(ghoAmount > 0, InvalidAmount());

        (, address stataToken) = _getTokensFromGsm(gsm);
        (uint256 assetAmount,,, uint256 fee) = IGSM(gsm).getAssetAmountForBuyAsset(ghoAmount);
        uint256 outputAmount = IStaticAToken(stataToken).previewRedeem(assetAmount);

        return (outputAmount, fee);
    }
}

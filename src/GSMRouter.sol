// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IStaticAToken} from "src/interfaces/IStaticAToken.sol";
import {IGSM} from "src/interfaces/IGSM.sol";
import {IGSMRouter} from "src/interfaces/IGSMRouter.sol";

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
    address public immutable sGHO;

    /// @inheritdoc IGSMRouter
    mapping(address => bool) public gsmAllowed;

    /**
     * @dev Constructor to initialize the contract
     * @param owner Address of the contract owner
     * @param gho Address of the GHO token on the deployed network
     */
    constructor(address owner, address gho, address sgho) Ownable(owner) {
        require(gho != address(0), ZeroAddress());
        require(sgho != address(0), ZeroAddress());

        GHO = gho;
        sGHO = sgho;
    }

    /// @inheritdoc IGSMRouter
    function swapToGHO(address gsm, uint256 amount, uint256 minGHOAmount) external returns (uint256) {
        require(amount > 0, InvalidAmount());
        _requireAllowedGsm(gsm);

        (address token, address stataToken) = _getTokensFromGsm(gsm);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        (uint256 inputAmountUsed, uint256 ghoAmount) = _sellUnderlyingForGho(gsm, token, stataToken, amount, msg.sender);

        require(ghoAmount >= minGHOAmount, SlippageExceeded());

        IERC20(GHO).safeTransfer(msg.sender, ghoAmount);

        emit SwapToGHO(msg.sender, token, inputAmountUsed, ghoAmount);

        return ghoAmount;
    }

    /// @inheritdoc IGSMRouter
    function swapFromGHO(address gsm, uint256 ghoAmount, uint256 minOutputAmount) external returns (uint256) {
        require(ghoAmount > 0, InvalidAmount());
        _requireAllowedGsm(gsm);

        (address token, address stataToken) = _getTokensFromGsm(gsm);

        IERC20(GHO).safeTransferFrom(msg.sender, address(this), ghoAmount);
        (uint256 outputAmount, uint256 ghoBurned) =
            _buyUnderlyingWithGho(gsm, stataToken, ghoAmount, msg.sender, msg.sender);

        require(outputAmount >= minOutputAmount, SlippageExceeded());

        emit SwapFromGHO(msg.sender, token, ghoBurned, outputAmount);

        return outputAmount;
    }

    /// @inheritdoc IGSMRouter
    function swapTosGHO(address gsm, uint256 amount, uint256 minSGHOAmount) external returns (uint256) {
        require(amount > 0, InvalidAmount());

        address inputToken = GHO;
        uint256 inputAmount = amount;
        uint256 ghoAmount = amount;

        if (gsm == address(0)) {
            IERC20(GHO).safeTransferFrom(msg.sender, address(this), amount);
        } else {
            _requireAllowedGsm(gsm);
            (address token, address stataToken) = _getTokensFromGsm(gsm);
            inputToken = token;

            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            (inputAmount, ghoAmount) = _sellUnderlyingForGho(gsm, token, stataToken, amount, msg.sender);
        }

        IERC20(GHO).forceApprove(sGHO, ghoAmount);
        uint256 sghoAmount = IERC4626(sGHO).deposit(ghoAmount, msg.sender);
        IERC20(GHO).forceApprove(sGHO, 0);

        require(sghoAmount >= minSGHOAmount, SlippageExceeded());

        emit SwapTosGHO(msg.sender, inputToken, sGHO, inputAmount, ghoAmount, sghoAmount);

        return sghoAmount;
    }

    /// @inheritdoc IGSMRouter
    function swapFromsGHO(address gsm, uint256 sghoAmount, uint256 minOutputAmount) external returns (uint256) {
        require(sghoAmount > 0, InvalidAmount());
        if (gsm != address(0)) {
            _requireAllowedGsm(gsm);
        }

        // Step 1: Redeem sGHO shares into GHO
        IERC20(sGHO).safeTransferFrom(msg.sender, address(this), sghoAmount);
        uint256 ghoAmount = IERC4626(sGHO).redeem(sghoAmount, address(this), address(this));

        // Direct path: sGHO -> GHO
        if (gsm == address(0)) {
            require(ghoAmount >= minOutputAmount, SlippageExceeded());

            IERC20(GHO).safeTransfer(msg.sender, ghoAmount);
            emit SwapFromsGHO(msg.sender, sGHO, GHO, sghoAmount, ghoAmount, ghoAmount);
            return ghoAmount;
        }

        // Path via GSM: sGHO -> GHO -> underlying token
        (address outputToken, address stataToken) = _getTokensFromGsm(gsm);

        (uint256 outputAmount, uint256 ghoBurned) =
            _buyUnderlyingWithGho(gsm, stataToken, ghoAmount, msg.sender, msg.sender);

        require(outputAmount >= minOutputAmount, SlippageExceeded());

        emit SwapFromsGHO(msg.sender, sGHO, outputToken, sghoAmount, ghoBurned, outputAmount);

        return outputAmount;
    }

    /// @inheritdoc IGSMRouter
    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    /// @inheritdoc IGSMRouter
    function setGsmAllowed(address gsm, bool allowed) external onlyOwner {
        require(gsm != address(0), ZeroAddress());
        if (allowed) {
            require(gsm.code.length != 0, InvalidGsm());
        }

        gsmAllowed[gsm] = allowed;
        emit GsmAllowedUpdated(gsm, allowed);
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
        return _previewBuyUnderlyingWithGho(gsm, stataToken, ghoAmount);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapTosGHO(address gsm, uint256 amount) external view returns (uint256, uint256) {
        require(amount > 0, InvalidAmount());

        uint256 ghoAmount = amount;
        uint256 fee;
        if (gsm != address(0)) {
            (, address stataToken) = _getTokensFromGsm(gsm);
            uint256 sharesAmount = IStaticAToken(stataToken).previewDeposit(amount);
            (, ghoAmount,, fee) = IGSM(gsm).getGhoAmountForSellAsset(sharesAmount);
        }

        uint256 sghoAmount = IERC4626(sGHO).previewDeposit(ghoAmount);
        return (sghoAmount, fee);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapFromsGHO(address gsm, uint256 sghoAmount) external view returns (uint256, uint256) {
        require(sghoAmount > 0, InvalidAmount());

        uint256 ghoAmount = IERC4626(sGHO).previewRedeem(sghoAmount);
        if (gsm == address(0)) {
            return (ghoAmount, 0);
        }

        (, address stataToken) = _getTokensFromGsm(gsm);
        return _previewBuyUnderlyingWithGho(gsm, stataToken, ghoAmount);
    }

    function _sellUnderlyingForGho(address gsm, address token, address stataToken, uint256 amount, address dustReceiver)
        internal
        returns (uint256, uint256)
    {
        IERC20(token).forceApprove(stataToken, amount);
        uint256 stataAmount = IStaticAToken(stataToken).deposit(amount, address(this));

        IERC20(stataToken).forceApprove(gsm, stataAmount);
        (uint256 assetSold, uint256 ghoBought) = IGSM(gsm).sellAsset(stataAmount, address(this));
        IERC20(stataToken).forceApprove(gsm, 0);

        uint256 inputAmountUsed = amount;
        if (assetSold < stataAmount) {
            uint256 dust = stataAmount - assetSold;
            uint256 dustRedeemed = IStaticAToken(stataToken).redeem(dust, dustReceiver, address(this));
            inputAmountUsed = amount - dustRedeemed;
            emit DustReturned(dustReceiver, token, dustRedeemed);
        }

        uint256 ghoAmount = ghoBought;
        return (inputAmountUsed, ghoAmount);
    }

    function _buyUnderlyingWithGho(
        address gsm,
        address stataToken,
        uint256 ghoAmount,
        address dustReceiver,
        address outputReceiver
    ) internal returns (uint256, uint256) {
        (uint256 stataAmountToBuy,,,) = IGSM(gsm).getAssetAmountForBuyAsset(ghoAmount);

        IERC20(GHO).forceApprove(gsm, ghoAmount);
        (uint256 stataAmount, uint256 ghoBurned) = IGSM(gsm).buyAsset(stataAmountToBuy, address(this));
        IERC20(GHO).forceApprove(gsm, 0);

        if (ghoBurned < ghoAmount) {
            uint256 ghoDust = ghoAmount - ghoBurned;
            IERC20(GHO).safeTransfer(dustReceiver, ghoDust);
            emit DustReturned(dustReceiver, GHO, ghoDust);
        }

        uint256 outputAmount = IStaticAToken(stataToken).redeem(stataAmount, outputReceiver, address(this));
        uint256 ghoAmountSpent = ghoBurned;
        return (outputAmount, ghoAmountSpent);
    }

    function _previewBuyUnderlyingWithGho(address gsm, address stataToken, uint256 ghoAmount)
        internal
        view
        returns (uint256, uint256)
    {
        (uint256 assetAmount,,, uint256 pathFee) = IGSM(gsm).getAssetAmountForBuyAsset(ghoAmount);
        uint256 outputAmount = IStaticAToken(stataToken).previewRedeem(assetAmount);
        uint256 fee = pathFee;
        return (outputAmount, fee);
    }

    function _requireAllowedGsm(address gsm) internal view {
        require(gsmAllowed[gsm], GsmNotAllowed());
    }

    function _getTokensFromGsm(address gsm) internal view returns (address, address) {
        require(gsm != address(0), ZeroAddress());
        require(gsm.code.length != 0, InvalidGsm());

        address token;
        address stataToken;
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

        return (token, stataToken);
    }
}

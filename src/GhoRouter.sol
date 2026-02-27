// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IStaticAToken} from "src/interfaces/IStaticAToken.sol";
import {IGSM} from "src/interfaces/IGSM.sol";
import {IGhoRouter} from "src/interfaces/IGhoRouter.sol";

/**
 * @title GhoRouter
 * @notice Router for token swaps through whitelisted GSMs and direct GHO/sGHO conversion paths
 * @dev This contract never stores user funds and uses exact approvals only
 */
contract GhoRouter is Ownable, IGhoRouter {
    using SafeERC20 for IERC20;

    /// @inheritdoc IGhoRouter
    address public immutable GHO;

    /// @inheritdoc IGhoRouter
    address public immutable sGHO;

    /// @inheritdoc IGhoRouter
    mapping(address gsm => bool allowed) public isGsmAllowed;

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

    /// @inheritdoc IGhoRouter
    function swapToGHO(address gsm, address token, uint256 amount, uint256 minGHOAmount) external returns (uint256) {
        return _swapToGHO(gsm, token, amount, minGHOAmount, msg.sender);
    }

    /// @inheritdoc IGhoRouter
    function swapToGHO(address gsm, address token, uint256 amount, uint256 minGHOAmount, address recipient)
        external
        returns (uint256)
    {
        return _swapToGHO(gsm, token, amount, minGHOAmount, recipient);
    }

    /// @inheritdoc IGhoRouter
    function swapFromGHO(address gsm, uint256 ghoAmount, uint256 minOutputAmount) external returns (uint256) {
        return _swapFromGHO(gsm, ghoAmount, minOutputAmount, msg.sender);
    }

    /// @inheritdoc IGhoRouter
    function swapFromGHO(address gsm, uint256 ghoAmount, uint256 minOutputAmount, address recipient)
        external
        returns (uint256)
    {
        return _swapFromGHO(gsm, ghoAmount, minOutputAmount, recipient);
    }

    /// @inheritdoc IGhoRouter
    function swapTosGHO(address gsm, address token, uint256 amount, uint256 minSGHOAmount) external returns (uint256) {
        return _swapTosGHO(gsm, token, amount, minSGHOAmount, msg.sender);
    }

    /// @inheritdoc IGhoRouter
    function swapTosGHO(address gsm, address token, uint256 amount, uint256 minSGHOAmount, address recipient)
        external
        returns (uint256)
    {
        return _swapTosGHO(gsm, token, amount, minSGHOAmount, recipient);
    }

    /// @inheritdoc IGhoRouter
    function swapTosGHO(uint256 ghoAmount, uint256 minSGHOAmount) external returns (uint256) {
        return _swapTosGHO(ghoAmount, minSGHOAmount, msg.sender);
    }

    /// @inheritdoc IGhoRouter
    function swapTosGHO(uint256 ghoAmount, uint256 minSGHOAmount, address recipient) external returns (uint256) {
        return _swapTosGHO(ghoAmount, minSGHOAmount, recipient);
    }

    /// @inheritdoc IGhoRouter
    function swapFromsGHO(address gsm, uint256 sghoAmount, uint256 minOutputAmount) external returns (uint256) {
        return _swapFromsGHO(gsm, sghoAmount, minOutputAmount, msg.sender);
    }

    /// @inheritdoc IGhoRouter
    function swapFromsGHO(address gsm, uint256 sghoAmount, uint256 minOutputAmount, address recipient)
        external
        returns (uint256)
    {
        return _swapFromsGHO(gsm, sghoAmount, minOutputAmount, recipient);
    }

    /// @inheritdoc IGhoRouter
    function swapFromsGHO(uint256 sghoAmount, uint256 minOutputAmount) external returns (uint256) {
        return _swapFromsGHO(sghoAmount, minOutputAmount, msg.sender);
    }

    /// @inheritdoc IGhoRouter
    function swapFromsGHO(uint256 sghoAmount, uint256 minOutputAmount, address recipient) external returns (uint256) {
        return _swapFromsGHO(sghoAmount, minOutputAmount, recipient);
    }

    /// @inheritdoc IGhoRouter
    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    /// @inheritdoc IGhoRouter
    function setGsmAllowed(address gsm, bool allowed) external onlyOwner {
        require(gsm != address(0), ZeroAddress());

        if (allowed) {
            _validateGsm(gsm);
        }

        isGsmAllowed[gsm] = allowed;
        emit GsmAllowedUpdated(gsm, allowed);
    }

    /// @inheritdoc IGhoRouter
    function previewSwapToGHO(address gsm, address token, uint256 amount) external view returns (uint256, uint256) {
        require(amount > 0, InvalidAmount());

        address stataToken = _getStataToken(gsm, token);
        uint256 sharesAmount = token == stataToken ? amount : IStaticAToken(stataToken).previewDeposit(amount);

        (, uint256 ghoAmount,, uint256 fee) = IGSM(gsm).getGhoAmountForSellAsset(sharesAmount);
        return (ghoAmount, fee);
    }

    /// @inheritdoc IGhoRouter
    function previewSwapFromGHO(address gsm, uint256 ghoAmount) external view returns (uint256, uint256) {
        require(ghoAmount > 0, InvalidAmount());

        (, address stataToken) = _getTokensFromGsm(gsm);
        return _previewBuyUnderlyingWithGho(gsm, stataToken, ghoAmount);
    }

    /// @inheritdoc IGhoRouter
    function previewSwapTosGHO(address gsm, address token, uint256 amount) external view returns (uint256, uint256) {
        require(amount > 0, InvalidAmount());

        address stataToken = _getStataToken(gsm, token);
        uint256 sharesAmount = token == stataToken ? amount : IStaticAToken(stataToken).previewDeposit(amount);
        (, uint256 ghoAmount,, uint256 fee) = IGSM(gsm).getGhoAmountForSellAsset(sharesAmount);

        uint256 sghoAmount = IERC4626(sGHO).previewDeposit(ghoAmount);
        return (sghoAmount, fee);
    }

    /// @inheritdoc IGhoRouter
    function previewSwapTosGHO(uint256 ghoAmount) external view returns (uint256) {
        require(ghoAmount > 0, InvalidAmount());
        return IERC4626(sGHO).previewDeposit(ghoAmount);
    }

    /// @inheritdoc IGhoRouter
    function previewSwapFromsGHO(address gsm, uint256 sghoAmount) external view returns (uint256, uint256) {
        require(sghoAmount > 0, InvalidAmount());

        uint256 ghoAmount = IERC4626(sGHO).previewRedeem(sghoAmount);
        (, address stataToken) = _getTokensFromGsm(gsm);
        return _previewBuyUnderlyingWithGho(gsm, stataToken, ghoAmount);
    }

    /// @inheritdoc IGhoRouter
    function previewSwapFromsGHO(uint256 sghoAmount) external view returns (uint256) {
        require(sghoAmount > 0, InvalidAmount());
        return IERC4626(sGHO).previewRedeem(sghoAmount);
    }

    function _swapToGHO(address gsm, address token, uint256 amount, uint256 minGHOAmount, address recipient)
        internal
        returns (uint256)
    {
        _validateInputs(amount, recipient, gsm);

        address stataToken = _getStataToken(gsm, token);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        (uint256 inputAmountUsed, uint256 ghoAmount) = _sellTokenForGho(gsm, token, stataToken, amount, minGHOAmount);
        IERC20(GHO).safeTransfer(recipient, ghoAmount);
        emit SwapToGHO(msg.sender, token, inputAmountUsed, ghoAmount);

        return ghoAmount;
    }

    function _swapFromGHO(address gsm, uint256 ghoAmount, uint256 minOutputAmount, address recipient)
        internal
        returns (uint256)
    {
        _validateInputs(ghoAmount, recipient, gsm);

        (address token, address stataToken) = _getTokensFromGsm(gsm);
        IERC20(GHO).safeTransferFrom(msg.sender, address(this), ghoAmount);

        (uint256 outputAmount, uint256 ghoSold) =
            _buyUnderlyingWithGho(gsm, stataToken, ghoAmount, recipient, minOutputAmount);
        emit SwapFromGHO(msg.sender, token, ghoSold, outputAmount);

        return outputAmount;
    }

    function _swapTosGHO(address gsm, address token, uint256 amount, uint256 minSGHOAmount, address recipient)
        internal
        returns (uint256)
    {
        _validateInputs(amount, recipient, gsm);

        address stataToken = _getStataToken(gsm, token);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        (uint256 inputAmountUsed, uint256 ghoAmount) = _sellTokenForGho(gsm, token, stataToken, amount, 0);
        uint256 sghoAmount = _depositToSgho(ghoAmount, recipient, minSGHOAmount);
        emit SwapTosGHO(msg.sender, token, sGHO, inputAmountUsed, ghoAmount, sghoAmount);

        return sghoAmount;
    }

    function _swapTosGHO(uint256 ghoAmount, uint256 minSGHOAmount, address recipient) internal returns (uint256) {
        _validateInputs(ghoAmount, recipient);

        IERC20(GHO).safeTransferFrom(msg.sender, address(this), ghoAmount);
        uint256 sghoAmount = _depositToSgho(ghoAmount, recipient, minSGHOAmount);
        emit SwapTosGHO(msg.sender, GHO, sGHO, ghoAmount, ghoAmount, sghoAmount);

        return sghoAmount;
    }

    function _swapFromsGHO(address gsm, uint256 sghoAmount, uint256 minOutputAmount, address recipient)
        internal
        returns (uint256)
    {
        _validateInputs(sghoAmount, recipient, gsm);

        uint256 ghoAmount = _redeemGho(sghoAmount, 0);
        (address outputToken, address stataToken) = _getTokensFromGsm(gsm);

        (uint256 outputAmount, uint256 ghoSold) =
            _buyUnderlyingWithGho(gsm, stataToken, ghoAmount, recipient, minOutputAmount);
        emit SwapFromsGHO(msg.sender, sGHO, outputToken, sghoAmount, ghoSold, outputAmount);

        return outputAmount;
    }

    function _swapFromsGHO(uint256 sghoAmount, uint256 minOutputAmount, address recipient) internal returns (uint256) {
        _validateInputs(sghoAmount, recipient);
        uint256 ghoAmount = _redeemGho(sghoAmount, minOutputAmount);

        IERC20(GHO).safeTransfer(recipient, ghoAmount);
        emit SwapFromsGHO(msg.sender, sGHO, GHO, sghoAmount, ghoAmount, ghoAmount);

        return ghoAmount;
    }

    function _depositToSgho(uint256 ghoAmount, address receiver, uint256 minSghoAmount) internal returns (uint256) {
        IERC20(GHO).forceApprove(sGHO, ghoAmount);
        uint256 sghoAmount = IERC4626(sGHO).deposit(ghoAmount, receiver);
        require(sghoAmount >= minSghoAmount, SlippageExceeded());
        return sghoAmount;
    }

    function _redeemGho(uint256 sghoAmount, uint256 minGhoAmount) internal returns (uint256) {
        IERC20(sGHO).safeTransferFrom(msg.sender, address(this), sghoAmount);
        uint256 ghoAmount = IERC4626(sGHO).redeem(sghoAmount, address(this), address(this));
        require(ghoAmount >= minGhoAmount, SlippageExceeded());
        return ghoAmount;
    }

    function _sellTokenForGho(address gsm, address token, address stataToken, uint256 amount, uint256 minGhoAmount)
        internal
        returns (uint256, uint256)
    {
        uint256 stataAmount = amount;
        if (token != stataToken) {
            IERC20(token).forceApprove(stataToken, amount);
            stataAmount = IStaticAToken(stataToken).deposit(amount, address(this));
        }

        IERC20(stataToken).forceApprove(gsm, stataAmount);
        (uint256 assetSold, uint256 ghoAmount) = IGSM(gsm).sellAsset(stataAmount, address(this));

        if (assetSold < stataAmount) {
            IStaticAToken(stataToken).redeem(stataAmount - assetSold, msg.sender, address(this));
        }

        require(ghoAmount >= minGhoAmount, SlippageExceeded());
        return (amount, ghoAmount);
    }

    function _buyUnderlyingWithGho(
        address gsm,
        address stataToken,
        uint256 ghoAmount,
        address outputReceiver,
        uint256 minOutputAmount
    ) internal returns (uint256, uint256) {
        (uint256 stataAmountToBuy,,,) = IGSM(gsm).getAssetAmountForBuyAsset(ghoAmount);

        IERC20(GHO).forceApprove(gsm, ghoAmount);
        (uint256 stataAmount, uint256 ghoSold) = IGSM(gsm).buyAsset(stataAmountToBuy, address(this));

        uint256 outputAmount = IStaticAToken(stataToken).redeem(stataAmount, outputReceiver, address(this));
        require(outputAmount >= minOutputAmount, SlippageExceeded());
        return (outputAmount, ghoSold);
    }

    function _previewBuyUnderlyingWithGho(address gsm, address stataToken, uint256 ghoAmount)
        internal
        view
        returns (uint256, uint256)
    {
        (uint256 assetAmount,,, uint256 pathFee) = IGSM(gsm).getAssetAmountForBuyAsset(ghoAmount);
        uint256 outputAmount = IStaticAToken(stataToken).previewRedeem(assetAmount);
        return (outputAmount, pathFee);
    }

    function _validateGsm(address gsm) internal view {
        require(gsm.code.length != 0, InvalidGsm());

        require(IGSM(gsm).GHO_TOKEN() == GHO, InvalidGsm());
        address stataToken = IGSM(gsm).UNDERLYING_ASSET();
        require(stataToken != address(0), InvalidGsm());

        require(IStaticAToken(stataToken).asset() != address(0), InvalidToken());
    }

    function _getTokensFromGsm(address gsm) internal view returns (address, address) {
        address stataToken = IGSM(gsm).UNDERLYING_ASSET();
        address token = IStaticAToken(stataToken).asset();
        return (token, stataToken);
    }

    function _getStataToken(address gsm, address token) internal view returns (address) {
        (address underlyingToken, address stataToken) = _getTokensFromGsm(gsm);
        require(token == underlyingToken || token == stataToken, InvalidToken());
        return stataToken;
    }

    function _validateInputs(uint256 amount, address recipient, address gsm) internal view {
        require(amount > 0, InvalidAmount());
        require(recipient != address(0), ZeroAddress());
        require(isGsmAllowed[gsm], GsmNotAllowed());
    }

    function _validateInputs(uint256 amount, address recipient) internal pure {
        require(amount > 0, InvalidAmount());
        require(recipient != address(0), ZeroAddress());
    }
}

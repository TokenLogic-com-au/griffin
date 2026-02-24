// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IStaticAToken} from "src/interfaces/IStaticAToken.sol";
import {IGSM} from "src/interfaces/IGSM.sol";
import {IGSMRouter} from "src/interfaces/onboarding/IGSMRouter.sol";

contract GSMRouter is Ownable, IGSMRouter {
    using SafeERC20 for IERC20;

    address internal immutable _GHO;
    address internal immutable _sGHO;
    address internal immutable _GSM_USDC;
    address internal immutable _GSM_USDT;
    address internal immutable _USDC;
    address internal immutable _USDT;
    address internal immutable _STATA_USDC;
    address internal immutable _STATA_USDT;

    constructor(address owner, address gho, address sgho, address gsmUsdc, address gsmUsdt) Ownable(owner) {
        require(gho != address(0), ZeroAddress());
        require(sgho != address(0), ZeroAddress());
        require(gsmUsdc != address(0), ZeroAddress());
        require(gsmUsdt != address(0), ZeroAddress());
        require(gsmUsdc != gsmUsdt, InvalidGsm());

        address vaultAsset;
        try IERC4626(sgho).asset() returns (address assetToken) {
            vaultAsset = assetToken;
        } catch {
            revert InvalidToken();
        }
        require(vaultAsset == gho, InvalidToken());

        _GHO = gho;
        _sGHO = sgho;

        (address usdcToken, address stataUsdc) = _getTokensFromGsm(gsmUsdc);
        (address usdtToken, address stataUsdt) = _getTokensFromGsm(gsmUsdt);
        require(usdcToken != usdtToken, InvalidToken());

        _GSM_USDC = gsmUsdc;
        _GSM_USDT = gsmUsdt;
        _USDC = usdcToken;
        _USDT = usdtToken;
        _STATA_USDC = stataUsdc;
        _STATA_USDT = stataUsdt;
    }

    /// @inheritdoc IGSMRouter
    function swapToGHO(address token, uint256 amount, uint256 minGHOAmount) external returns (uint256) {
        if (amount < 1) revert InvalidAmount();

        (uint256 ghoReceived, uint256 inputAmountSold) = _swapUnderlyingToGho(token, amount, msg.sender);

        require(ghoReceived >= minGHOAmount, SlippageExceeded());

        IERC20(_GHO).safeTransfer(msg.sender, ghoReceived);

        emit SwapToGHO(msg.sender, token, inputAmountSold, ghoReceived);

        return ghoReceived;
    }

    /// @inheritdoc IGSMRouter
    function swapFromGHO(address token, uint256 ghoAmount, uint256 minOutputAmount) external returns (uint256) {
        if (ghoAmount < 1) revert InvalidAmount();
        (address gsm, address stataToken) = _getRoute(token);

        IERC20(_GHO).safeTransferFrom(msg.sender, address(this), ghoAmount);
        (uint256 outputAmount, uint256 ghoBurned) =
            _swapGhoToUnderlying(gsm, stataToken, ghoAmount, minOutputAmount, msg.sender);

        emit SwapFromGHO(msg.sender, token, ghoBurned, outputAmount);

        return outputAmount;
    }

    /// @inheritdoc IGSMRouter
    function swapTosGHO(address token, uint256 amount, uint256 minOut) external returns (uint256) {
        if (amount < 1) revert InvalidAmount();
        uint256 ghoBalanceBefore = IERC20(_GHO).balanceOf(address(this));

        uint256 inputAmountSold = amount;
        uint256 ghoAmount;

        if (token == _GHO) {
            IERC20(_GHO).safeTransferFrom(msg.sender, address(this), amount);
            ghoAmount = amount;
        } else {
            (ghoAmount, inputAmountSold) = _swapUnderlyingToGho(token, amount, msg.sender);
        }

        // Step 3: Deposit GHO into sGHO vault
        IERC20(_GHO).forceApprove(_sGHO, ghoAmount);
        uint256 sghoAmount = IERC4626(_sGHO).deposit(ghoAmount, msg.sender);
        IERC20(_GHO).forceApprove(_sGHO, 0);

        // Return unexpected residual GHO if vault did not consume all GHO
        uint256 afterGhoBalance = IERC20(_GHO).balanceOf(address(this));
        if (afterGhoBalance > ghoBalanceBefore) {
            uint256 ghoDust = afterGhoBalance - ghoBalanceBefore;
            IERC20(_GHO).safeTransfer(msg.sender, ghoDust);
            emit DustReturned(msg.sender, _GHO, ghoDust);
        }

        require(sghoAmount >= minOut, SlippageExceeded());

        emit SwapTosGHO(msg.sender, token, _sGHO, inputAmountSold, ghoAmount, sghoAmount);

        return sghoAmount;
    }

    /// @inheritdoc IGSMRouter
    function swapFromsGHO(address token, uint256 amount, uint256 minOut) external returns (uint256) {
        if (amount < 1) revert InvalidAmount();

        // Step 1: Redeem sGHO shares into GHO
        IERC20(_sGHO).safeTransferFrom(msg.sender, address(this), amount);
        uint256 ghoBalanceBeforeRedeem = IERC20(_GHO).balanceOf(address(this));
        IERC4626(_sGHO).redeem(amount, address(this), address(this));
        uint256 ghoAmount = IERC20(_GHO).balanceOf(address(this)) - ghoBalanceBeforeRedeem;

        if (token == _GHO) {
            require(ghoAmount >= minOut, SlippageExceeded());
            IERC20(_GHO).safeTransfer(msg.sender, ghoAmount);
            emit SwapFromsGHO(msg.sender, _sGHO, _GHO, amount, ghoAmount, ghoAmount);
            return ghoAmount;
        }

        (address gsm, address stataToken) = _getRoute(token);
        (uint256 outputAmount,) = _swapGhoToUnderlying(gsm, stataToken, ghoAmount, minOut, msg.sender);

        emit SwapFromsGHO(msg.sender, _sGHO, token, amount, ghoAmount, outputAmount);

        return outputAmount;
    }

    /// @inheritdoc IGSMRouter
    function rescueToken(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(0), ZeroAddress());
        require(to != address(0), ZeroAddress());
        IERC20(token).safeTransfer(to, amount);
    }

    /// @inheritdoc IGSMRouter
    function GHO() external view returns (address) {
        return _GHO;
    }

    /// @inheritdoc IGSMRouter
    function sGHO() external view returns (address) {
        return _sGHO;
    }

    /// @inheritdoc IGSMRouter
    function GSM_USDC() external view returns (address) {
        return _GSM_USDC;
    }

    /// @inheritdoc IGSMRouter
    function GSM_USDT() external view returns (address) {
        return _GSM_USDT;
    }

    /// @inheritdoc IGSMRouter
    function previewSwapTosGHO(address token, uint256 amount) external view returns (uint256, uint256) {
        if (amount < 1) revert InvalidAmount();

        uint256 ghoAmount;
        uint256 fee;
        if (token == _GHO) {
            ghoAmount = amount;
        } else {
            (address gsm, address stataToken) = _getRoute(token);
            uint256 sharesAmount = IStaticAToken(stataToken).previewDeposit(amount);
            (, ghoAmount,, fee) = IGSM(gsm).getGhoAmountForSellAsset(sharesAmount);
        }

        uint256 sghoAmount = IERC4626(_sGHO).previewDeposit(ghoAmount);
        return (sghoAmount, fee);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapToGHO(address token, uint256 amount) external view returns (uint256, uint256) {
        if (amount < 1) revert InvalidAmount();

        (address gsm, address stataToken) = _getRoute(token);

        uint256 sharesAmount = IStaticAToken(stataToken).previewDeposit(amount);

        // This is a simplified preview:
        // Actual amount may vary slightly due to interest accrual in Aave
        (, uint256 ghoAmount,, uint256 fee) = IGSM(gsm).getGhoAmountForSellAsset(sharesAmount);
        return (ghoAmount, fee);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapFromGHO(address token, uint256 ghoAmount) external view returns (uint256, uint256) {
        if (ghoAmount < 1) revert InvalidAmount();

        (address gsm, address stataToken) = _getRoute(token);
        return _previewSwapFromGho(gsm, stataToken, ghoAmount);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapFromsGHO(address token, uint256 amount) external view returns (uint256, uint256) {
        if (amount < 1) revert InvalidAmount();

        uint256 ghoAmount = IERC4626(_sGHO).previewRedeem(amount);
        if (token == _GHO) {
            return (ghoAmount, 0);
        }

        (address gsm, address stataToken) = _getRoute(token);
        return _previewSwapFromGho(gsm, stataToken, ghoAmount);
    }

    function _getRoute(address token) internal view returns (address, address) {
        if (token == _USDC) {
            return (_GSM_USDC, _STATA_USDC);
        }
        if (token == _USDT) {
            return (_GSM_USDT, _STATA_USDT);
        }

        revert InvalidToken();
    }

    function _getTokensFromGsm(address gsm) internal view returns (address, address) {
        require(gsm != address(0), ZeroAddress());
        require(gsm.code.length != 0, InvalidGsm());

        address ghoToken;
        address stataToken;
        try IGSM(gsm).GHO_TOKEN() returns (address ghoFromGsm) {
            ghoToken = ghoFromGsm;
        } catch {
            revert InvalidGsm();
        }
        require(ghoToken == _GHO, InvalidGsm());

        // Get the stataToken from the GSM contract as GSMs hold stata as underlying asset
        try IGSM(gsm).UNDERLYING_ASSET() returns (address stataFromGsm) {
            stataToken = stataFromGsm;
        } catch {
            revert InvalidGsm();
        }
        require(stataToken != address(0), InvalidGsm());

        // Get the plain token (USDC/USDT) from the stataToken as stataTokens hold these in a vault
        address token;
        try IStaticAToken(stataToken).asset() returns (address underlyingToken) {
            token = underlyingToken;
        } catch {
            revert InvalidToken();
        }
        require(token != address(0), InvalidToken());
        return (token, stataToken);
    }

    function _swapUnderlyingToGho(address token, uint256 amount, address user) internal returns (uint256, uint256) {
        (address gsm, address stataToken) = _getRoute(token);
        IERC20(token).safeTransferFrom(user, address(this), amount);

        IERC20(token).forceApprove(stataToken, amount);
        uint256 stataAmount = IStaticAToken(stataToken).deposit(amount, address(this));
        IERC20(token).forceApprove(stataToken, 0);

        uint256 ghoBalanceBeforeSell = IERC20(_GHO).balanceOf(address(this));
        IERC20(stataToken).forceApprove(gsm, stataAmount);
        (uint256 assetSold,) = IGSM(gsm).sellAsset(stataAmount, address(this));
        IERC20(stataToken).forceApprove(gsm, 0);

        uint256 dustRedeemed;
        if (assetSold < stataAmount) {
            uint256 dust = stataAmount - assetSold;
            dustRedeemed = IStaticAToken(stataToken).redeem(dust, user, address(this));
            emit DustReturned(user, token, dustRedeemed);
        }

        uint256 ghoAmount = IERC20(_GHO).balanceOf(address(this)) - ghoBalanceBeforeSell;
        return (ghoAmount, amount - dustRedeemed);
    }

    function _previewSwapFromGho(address gsm, address stataToken, uint256 ghoAmount)
        internal
        view
        returns (uint256, uint256)
    {
        (uint256 assetAmount,,, uint256 fee) = IGSM(gsm).getAssetAmountForBuyAsset(ghoAmount);
        uint256 outputAmount = IStaticAToken(stataToken).previewRedeem(assetAmount);
        return (outputAmount, fee);
    }

    function _swapGhoToUnderlying(address gsm, address stataToken, uint256 ghoAmount, uint256 minOut, address recipient)
        internal
        returns (uint256, uint256)
    {
        if (ghoAmount < 1) {
            if (minOut != 0) revert SlippageExceeded();
            return (0, 0);
        }

        (uint256 stataAmountToBuy,,,) = IGSM(gsm).getAssetAmountForBuyAsset(ghoAmount);
        uint256 ghoBalanceBeforeBuy = IERC20(_GHO).balanceOf(address(this));
        uint256 stataBalanceBeforeBuy = IERC20(stataToken).balanceOf(address(this));

        IERC20(_GHO).forceApprove(gsm, ghoAmount);
        IGSM(gsm).buyAsset(stataAmountToBuy, address(this));
        IERC20(_GHO).forceApprove(gsm, 0);

        uint256 ghoBurned = ghoBalanceBeforeBuy - IERC20(_GHO).balanceOf(address(this));
        uint256 stataAmount = IERC20(stataToken).balanceOf(address(this)) - stataBalanceBeforeBuy;

        if (ghoBurned < ghoAmount) {
            uint256 ghoDust = ghoAmount - ghoBurned;
            IERC20(_GHO).safeTransfer(recipient, ghoDust);
            emit DustReturned(recipient, _GHO, ghoDust);
        }

        uint256 outputAmount = IStaticAToken(stataToken).redeem(stataAmount, recipient, address(this));
        require(outputAmount >= minOut, SlippageExceeded());
        return (outputAmount, ghoBurned);
    }
}

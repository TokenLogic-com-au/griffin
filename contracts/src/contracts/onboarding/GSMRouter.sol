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
        require(amount > 0, InvalidAmount());

        (address gsm, address stataToken) = _getRoute(token);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Step 1: Deposit underlying asset to stataToken
        IERC20(token).forceApprove(stataToken, amount);
        uint256 stataAmount = IStaticAToken(stataToken).deposit(amount, address(this));
        IERC20(token).forceApprove(stataToken, 0);

        // Step 2: Swap stataToken for GHO via GSM
        uint256 ghoBalanceBeforeSell = IERC20(_GHO).balanceOf(address(this));
        IERC20(stataToken).forceApprove(gsm, stataAmount);
        (uint256 assetSold,) = IGSM(gsm).sellAsset(stataAmount, address(this));

        // Clear residual allowance
        IERC20(stataToken).forceApprove(gsm, 0);

        uint256 ghoReceived = IERC20(_GHO).balanceOf(address(this)) - ghoBalanceBeforeSell;

        // Handle stataToken dust if GSM didn't consume full amount
        uint256 dustRedeemed;
        if (assetSold < stataAmount) {
            uint256 dust = stataAmount - assetSold;
            dustRedeemed = IStaticAToken(stataToken).redeem(dust, msg.sender, address(this));
            emit DustReturned(msg.sender, token, dustRedeemed);
        }

        require(ghoReceived >= minGHOAmount, SlippageExceeded());

        IERC20(_GHO).safeTransfer(msg.sender, ghoReceived);

        emit SwapToGHO(msg.sender, token, amount - dustRedeemed, ghoReceived);

        return ghoReceived;
    }

    /// @inheritdoc IGSMRouter
    function swapFromGHO(address token, uint256 ghoAmount, uint256 minOutputAmount) external returns (uint256) {
        require(ghoAmount > 0, InvalidAmount());

        (address gsm, address stataToken) = _getRoute(token);

        IERC20(_GHO).safeTransferFrom(msg.sender, address(this), ghoAmount);

        // Step 1: Calculate exact stataToken amount to buy with GHO
        (uint256 stataAmountToBuy,,,) = IGSM(gsm).getAssetAmountForBuyAsset(ghoAmount);

        // Step 2: Swap GHO for stataToken via GSM
        uint256 ghoBalanceBeforeBuy = IERC20(_GHO).balanceOf(address(this));
        uint256 stataBalanceBeforeBuy = IERC20(stataToken).balanceOf(address(this));

        IERC20(_GHO).forceApprove(gsm, ghoAmount);
        IGSM(gsm).buyAsset(stataAmountToBuy, address(this));

        // Clear residual allowance
        IERC20(_GHO).forceApprove(gsm, 0);

        uint256 ghoBurned = ghoBalanceBeforeBuy - IERC20(_GHO).balanceOf(address(this));
        uint256 stataAmount = IERC20(stataToken).balanceOf(address(this)) - stataBalanceBeforeBuy;

        // Handle GHO dust if GSM didn't burn full amount
        if (ghoBurned < ghoAmount) {
            uint256 ghoDust = ghoAmount - ghoBurned;
            IERC20(_GHO).safeTransfer(msg.sender, ghoDust);
            emit DustReturned(msg.sender, _GHO, ghoDust);
        }

        // Step 3: Redeem stataToken for underlying asset
        uint256 outputAmount = IStaticAToken(stataToken).redeem(stataAmount, msg.sender, address(this));

        require(outputAmount >= minOutputAmount, SlippageExceeded());

        emit SwapFromGHO(msg.sender, token, ghoBurned, outputAmount);

        return outputAmount;
    }

    /// @inheritdoc IGSMRouter
    function swapTosGHO(address token, uint256 amount, uint256 minOut) external returns (uint256) {
        require(amount > 0, InvalidAmount());
        uint256 ghoBalanceBefore = IERC20(_GHO).balanceOf(address(this));

        uint256 inputAmountSold = amount;
        uint256 ghoAmount;

        if (token == _GHO) {
            IERC20(_GHO).safeTransferFrom(msg.sender, address(this), amount);
            ghoAmount = amount;
        } else {
            (address gsm, address stataToken) = _getRoute(token);

            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

            // Step 1: Deposit underlying asset to stataToken
            IERC20(token).forceApprove(stataToken, amount);
            uint256 stataAmount = IStaticAToken(stataToken).deposit(amount, address(this));
            IERC20(token).forceApprove(stataToken, 0);

            // Step 2: Swap stataToken for GHO via GSM
            uint256 ghoBalanceBeforeSell = IERC20(_GHO).balanceOf(address(this));
            IERC20(stataToken).forceApprove(gsm, stataAmount);
            (uint256 assetSold,) = IGSM(gsm).sellAsset(stataAmount, address(this));

            // Clear residual allowance
            IERC20(stataToken).forceApprove(gsm, 0);

            // Handle stataToken dust if GSM didn't consume full amount
            uint256 dustRedeemed;
            if (assetSold < stataAmount) {
                uint256 dust = stataAmount - assetSold;
                dustRedeemed = IStaticAToken(stataToken).redeem(dust, msg.sender, address(this));
                emit DustReturned(msg.sender, token, dustRedeemed);
            }

            inputAmountSold = amount - dustRedeemed;
            ghoAmount = IERC20(_GHO).balanceOf(address(this)) - ghoBalanceBeforeSell;
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
    function previewSwapToGHO(address token, uint256 amount) external view returns (uint256, uint256) {
        require(amount > 0, InvalidAmount());

        (address gsm, address stataToken) = _getRoute(token);

        uint256 sharesAmount = IStaticAToken(stataToken).previewDeposit(amount);

        // This is a simplified preview:
        // Actual amount may vary slightly due to interest accrual in Aave
        (, uint256 ghoAmount,, uint256 fee) = IGSM(gsm).getGhoAmountForSellAsset(sharesAmount);
        return (ghoAmount, fee);
    }

    /// @inheritdoc IGSMRouter
    function previewSwapFromGHO(address token, uint256 ghoAmount) external view returns (uint256, uint256) {
        require(ghoAmount > 0, InvalidAmount());

        (address gsm, address stataToken) = _getRoute(token);
        (uint256 assetAmount,,, uint256 fee) = IGSM(gsm).getAssetAmountForBuyAsset(ghoAmount);
        uint256 outputAmount = IStaticAToken(stataToken).previewRedeem(assetAmount);

        return (outputAmount, fee);
    }

    function _getRoute(address token) internal view returns (address gsm, address stataToken) {
        if (token == _USDC) {
            return (_GSM_USDC, _STATA_USDC);
        }
        if (token == _USDT) {
            return (_GSM_USDT, _STATA_USDT);
        }

        revert InvalidToken();
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
        require(ghoToken == _GHO, InvalidGsm());

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
}

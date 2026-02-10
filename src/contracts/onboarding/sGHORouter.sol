// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IGSM} from "src/interfaces/IGSM.sol";
import {IStaticAToken} from "src/interfaces/IStaticAToken.sol";
import {IGSMRouter} from "src/interfaces/onboarding/IGSMRouter.sol";
import {ISGHORouter} from "src/interfaces/onboarding/ISGHORouter.sol";

/**
 * @title SGHORouter
 * @notice Helper wrapper to route USDC/USDT/GHO into and out of sGHO in a single call.
 * @dev The helper does not keep user funds; any residual token dust is forwarded back to caller.
 */
contract sGHORouter is ISGHORouter {
    using SafeERC20 for IERC20;

    /// @inheritdoc ISGHORouter
    address public immutable GSM_ROUTER;
    /// @inheritdoc ISGHORouter
    address public immutable SGHO;
    /// @inheritdoc ISGHORouter
    address public immutable GHO;
    /// @inheritdoc ISGHORouter
    address public immutable USDC;
    /// @inheritdoc ISGHORouter
    address public immutable USDT;
    /// @inheritdoc ISGHORouter
    address public immutable GSM_USDC;
    /// @inheritdoc ISGHORouter
    address public immutable GSM_USDT;

    /**
     * @param gsmRouter Address of deployed GSMRouter.
     * @param sgho Address of sGHO (ERC4626 GHO vault).
     * @param gho Address of GHO token.
     * @param usdc Address of USDC token.
     * @param usdt Address of USDT token.
     * @param gsmUsdc GSM used to route USDC<->GHO.
     * @param gsmUsdt GSM used to route USDT<->GHO.
     */
    constructor(
        address gsmRouter,
        address sgho,
        address gho,
        address usdc,
        address usdt,
        address gsmUsdc,
        address gsmUsdt
    ) {
        require(
            gsmRouter != address(0) && sgho != address(0) && gho != address(0) && usdc != address(0)
                && usdt != address(0) && gsmUsdc != address(0) && gsmUsdt != address(0),
            ZeroAddress()
        );

        GSM_ROUTER = gsmRouter;
        SGHO = sgho;
        GHO = gho;
        USDC = usdc;
        USDT = usdt;
        GSM_USDC = gsmUsdc;
        GSM_USDT = gsmUsdt;

        _validateConfiguration();
    }

    /// @inheritdoc ISGHORouter
    function deposit(address token, uint256 amount) external returns (uint256 shares) {
        require(amount > 0, InvalidAmount());

        uint256 preGhoBalance = IERC20(GHO).balanceOf(address(this));
        uint256 preInputBalance;
        bool routedViaGsm;
        uint256 ghoAmount;

        if (token == GHO) {
            IERC20(GHO).safeTransferFrom(msg.sender, address(this), amount);
            ghoAmount = amount;
        } else {
            address gsm = _getGsmForToken(token);
            preInputBalance = IERC20(token).balanceOf(address(this));
            routedViaGsm = true;

            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            IERC20(token).forceApprove(GSM_ROUTER, amount);
            ghoAmount = IGSMRouter(GSM_ROUTER).swapToGHO(gsm, amount, 0);
            IERC20(token).forceApprove(GSM_ROUTER, 0);
        }

        IERC20(GHO).forceApprove(SGHO, ghoAmount);
        shares = IERC4626(SGHO).deposit(ghoAmount, msg.sender);
        IERC20(GHO).forceApprove(SGHO, 0);

        if (routedViaGsm) _returnDust(token, preInputBalance, msg.sender);
        _returnDust(GHO, preGhoBalance, msg.sender);

        emit Deposited(msg.sender, token, amount, ghoAmount, shares);
    }

    /// @inheritdoc ISGHORouter
    function redeem(uint256 shares, address token) external returns (uint256 amountOut) {
        require(shares > 0, InvalidAmount());

        if (token == GHO) {
            amountOut = IERC4626(SGHO).redeem(shares, msg.sender, msg.sender);
            emit Redeemed(msg.sender, token, shares, amountOut);
            return amountOut;
        }

        address gsm = _getGsmForToken(token);
        uint256 preOutputBalance = IERC20(token).balanceOf(address(this));
        uint256 preGhoBalance = IERC20(GHO).balanceOf(address(this));

        uint256 ghoAmount = IERC4626(SGHO).redeem(shares, address(this), msg.sender);

        IERC20(GHO).forceApprove(GSM_ROUTER, ghoAmount);
        IGSMRouter(GSM_ROUTER).swapFromGHO(gsm, ghoAmount, 0);
        IERC20(GHO).forceApprove(GSM_ROUTER, 0);

        amountOut = _transferBalanceDelta(token, preOutputBalance, msg.sender);
        _returnDust(GHO, preGhoBalance, msg.sender);

        emit Redeemed(msg.sender, token, shares, amountOut);
    }

    function _validateConfiguration() internal view {
        require(GSM_ROUTER.code.length > 0 && SGHO.code.length > 0, InvalidConfiguration());
        require(IGSMRouter(GSM_ROUTER).GHO() == GHO, InvalidConfiguration());
        require(IERC4626(SGHO).asset() == GHO, InvalidConfiguration());

        _validateGsm(GSM_USDC, USDC);
        _validateGsm(GSM_USDT, USDT);
    }

    function _validateGsm(address gsm, address expectedToken) internal view {
        require(gsm.code.length > 0, InvalidConfiguration());

        address ghoFromGsm;
        try IGSM(gsm).GHO_TOKEN() returns (address ghoToken) {
            ghoFromGsm = ghoToken;
        } catch {
            revert InvalidConfiguration();
        }
        require(ghoFromGsm == GHO, InvalidConfiguration());

        address stataToken;
        try IGSM(gsm).UNDERLYING_ASSET() returns (address stata) {
            stataToken = stata;
        } catch {
            revert InvalidConfiguration();
        }
        require(stataToken.code.length > 0, InvalidConfiguration());

        address underlying;
        try IStaticAToken(stataToken).asset() returns (address assetToken) {
            underlying = assetToken;
        } catch {
            revert InvalidConfiguration();
        }
        require(underlying == expectedToken, InvalidConfiguration());
    }

    function _getGsmForToken(address token) internal view returns (address) {
        if (token == USDC) return GSM_USDC;
        if (token == USDT) return GSM_USDT;
        revert InvalidToken();
    }

    function _transferBalanceDelta(address token, uint256 preBalance, address receiver)
        internal
        returns (uint256 delta)
    {
        uint256 postBalance = IERC20(token).balanceOf(address(this));
        if (postBalance <= preBalance) return 0;

        delta = postBalance - preBalance;
        IERC20(token).safeTransfer(receiver, delta);
    }

    function _returnDust(address token, uint256 preBalance, address receiver) internal {
        uint256 dust = _transferBalanceDelta(token, preBalance, receiver);
        if (dust == 0) return;

        emit DustReturned(receiver, token, dust);
    }
}

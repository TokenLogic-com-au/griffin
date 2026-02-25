// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IGsm} from "../interfaces/IGsm.sol";
import {IStaticAToken} from "../interfaces/IStaticAToken.sol";
import {IGhoRouter} from "./IGhoRouter.sol";

contract GhoRouter is IGhoRouter, Ownable {
    using SafeERC20 for IERC20;

    address public immutable GHO;
    address public immutable sGHO;

    constructor(
        address initialOwner,
        address gho,
        address sGho
    ) Ownable(initialOwner) {
        require(gho != address(0), ZeroAddress());
        require(sGho != address(0), ZeroAddress());
        GHO = gho;
        sGHO = sGho;
    }

    function swapToGho(
        address gsm,
        address token,
        uint256 amount,
        uint256 minOut
    ) external returns (uint256) {
        uint256 acquired = _swapToGho(gsm, token, amount, minOut);
        IERC20(GHO).safeTransfer(msg.sender, acquired);
        return acquired;
    }

    function swapToGho(
        address gsm,
        address token,
        uint256 amount,
        uint256 minOut,
        address recipient
    ) external returns (uint256) {
        uint256 acquired = _swapToGho(gsm, token, amount, minOut);
        IERC20(GHO).safeTransfer(recipient, acquired);
        return acquired;
    }

    function swapToSGho(
        address gsm,
        address token,
        uint256 amount,
        uint256 minOut
    ) external returns (uint256) {
        uint256 acquired = _swapToGho(gsm, token, amount, minOut);
        return _swapToSGho(acquired, minOut, msg.sender);
    }

    function swapToSGho(
        address gsm,
        address token,
        uint256 amount,
        uint256 minOut,
        address recipient
    ) external returns (uint256) {
        uint256 acquired = _swapToGho(gsm, token, amount, minOut);
        return _swapToSGho(acquired, minOut, recipient);
    }

    function rescueToken(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(token != address(0), ZeroAddress());
        require(to != address(0), ZeroAddress());
        IERC20(token).safeTransfer(to, amount);
    }

    function _swapToGho(
        address gsm,
        address token,
        uint256 amount,
        uint256 minOut
    ) internal returns (uint256) {
        if (amount < 1) revert InvalidAmount();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 acquired = _performSwapTo(gsm, token, amount);
        require(acquired >= minOut, SlippageExceeded());

        // Emit?? GSM already emits so not sure if necessary.

        return acquired;
    }

    function _swapToSGho(
        uint256 amount,
        uint256 minOut,
        address recipient
    ) internal returns (uint256) {
        IERC20(GHO).forceApprove(sGHO, amount);
        uint256 acquired = IERC4626(sGHO).deposit(amount, recipient);

        require(acquired >= minOut, SlippageExceeded());

        return acquired;
    }

    function _performSwapTo(
        address gsm,
        address token,
        uint256 amount
    ) internal returns (uint256) {
        address stata = IGsm(gsm).UNDERLYING_ASSET();
        uint256 stataAmount;
        if (token != stata) {
            IERC20(token).forceApprove(stata, amount);
            stataAmount = IStaticAToken(stata).deposit(amount, address(this));
        } else {
            stataAmount = amount;
        }

        IERC20(stata).forceApprove(gsm, stataAmount);
        (uint256 assetSold, uint256 ghoAmount) = IGsm(gsm).sellAsset(
            stataAmount,
            address(this)
        );

        if (assetSold < stataAmount) {
            IStaticAToken(stata).redeem(
                stataAmount - assetSold,
                msg.sender,
                address(this)
            );
        }

        return ghoAmount;
    }
}

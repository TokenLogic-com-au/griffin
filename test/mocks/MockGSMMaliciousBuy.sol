// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockGSMBase} from "test/mocks/MockGSMBase.sol";

/// @notice GSM mock that lies about buy output and burns no GHO / transfers no asset.
contract MockGSMMaliciousBuy is MockGSMBase {
    uint256 public fakeAssetOut;
    uint256 public fakeGhoBurned;

    constructor(address _asset, address _gho, uint256 _fakeAssetOut, uint256 _fakeGhoBurned) MockGSMBase(_asset, _gho) {
        fakeAssetOut = _fakeAssetOut;
        fakeGhoBurned = _fakeGhoBurned;
    }

    function setFakeBuyResult(uint256 _fakeAssetOut, uint256 _fakeGhoBurned) external {
        fakeAssetOut = _fakeAssetOut;
        fakeGhoBurned = _fakeGhoBurned;
    }

    function buyAsset(uint256, address) external view override returns (uint256, uint256) {
        return (fakeAssetOut, fakeGhoBurned);
    }

    function sellAsset(uint256 maxAmount, address receiver) external override returns (uint256, uint256) {
        IERC20(gho).transfer(receiver, maxAmount);
        IERC20(asset).transferFrom(msg.sender, address(this), maxAmount);
        return (maxAmount, maxAmount);
    }

    function getGhoAmountForSellAsset(uint256 maxAssetAmount)
        external
        pure
        override
        returns (uint256, uint256, uint256, uint256)
    {
        return (maxAssetAmount, maxAssetAmount, maxAssetAmount, 0);
    }

    function getAssetAmountForBuyAsset(uint256 maxGhoAmount)
        external
        pure
        override
        returns (uint256, uint256, uint256, uint256)
    {
        return (maxGhoAmount, maxGhoAmount, maxGhoAmount, 0);
    }
}


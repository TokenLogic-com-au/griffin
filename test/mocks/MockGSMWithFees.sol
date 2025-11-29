// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockGSMBase} from "test/mocks/MockGSMBase.sol";

/// @notice GSM mock with configurable fees (basis points)
contract MockGSMWithFees is MockGSMBase {
    uint256 public feeBps; // Fee in basis points (100 = 1%)

    constructor(address _asset, address _gho, uint256 _feeBps) MockGSMBase(_asset, _gho) {
        feeBps = _feeBps;
    }

    function setFeeBps(uint256 _feeBps) external {
        feeBps = _feeBps;
    }

    function buyAsset(uint256 minAmount, address receiver) external override returns (uint256, uint256) {
        // Calculate GHO needed including fee
        uint256 ghoNeeded = (minAmount * 10000) / (10000 - feeBps);

        // Transfer Asset to receiver
        IERC20(asset).transfer(receiver, minAmount);
        // Pull GHO from msg.sender
        IERC20(gho).transferFrom(msg.sender, address(this), ghoNeeded);

        return (minAmount, ghoNeeded);
    }

    function sellAsset(uint256 maxAmount, address receiver) external override returns (uint256, uint256) {
        // Calculate GHO output after fee
        uint256 fee = (maxAmount * feeBps) / 10000;
        uint256 ghoAmount = maxAmount - fee;

        // Transfer GHO to receiver
        IERC20(gho).transfer(receiver, ghoAmount);
        // Pull Asset from msg.sender
        IERC20(asset).transferFrom(msg.sender, address(this), maxAmount);

        return (maxAmount, ghoAmount);
    }

    function getGhoAmountForBuyAsset(uint256 minAssetAmount)
        external
        view
        override
        returns (uint256, uint256, uint256, uint256)
    {
        uint256 ghoNeeded = (minAssetAmount * 10000) / (10000 - feeBps);
        uint256 fee = ghoNeeded - minAssetAmount;
        return (ghoNeeded, minAssetAmount, ghoNeeded, fee);
    }

    function getGhoAmountForSellAsset(uint256 maxAssetAmount)
        external
        view
        override
        returns (uint256, uint256, uint256, uint256)
    {
        uint256 fee = (maxAssetAmount * feeBps) / 10000;
        uint256 ghoAmount = maxAssetAmount - fee;
        return (maxAssetAmount, ghoAmount, maxAssetAmount, fee);
    }

    function getAssetAmountForBuyAsset(uint256 maxGhoAmount)
        external
        view
        override
        returns (uint256, uint256, uint256, uint256)
    {
        uint256 fee = (maxGhoAmount * feeBps) / 10000;
        uint256 assetAmount = maxGhoAmount - fee;
        return (assetAmount, maxGhoAmount, maxGhoAmount, fee);
    }

    function getAssetAmountForSellAsset(uint256 minGhoAmount)
        external
        view
        override
        returns (uint256, uint256, uint256, uint256)
    {
        uint256 assetNeeded = (minGhoAmount * 10000) / (10000 - feeBps);
        uint256 fee = assetNeeded - minGhoAmount;
        return (assetNeeded, minGhoAmount, assetNeeded, fee);
    }

    function getAvailableLiquidity() external view override returns (uint256) {
        return type(uint256).max;
    }

    function canSwap() external view override returns (bool) {
        return !frozen;
    }
}

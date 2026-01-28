// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockGSMBase} from "test/mocks/MockGSMBase.sol";

/// @notice GSM mock with configurable fees (basis points) and partial consumption
contract MockGSMWithFees is MockGSMBase {
    uint256 public feeBps; // Fee in basis points (100 = 1%)
    uint256 public consumptionBps = 10000; // Consumption rate in basis points (10000 = 100%)

    constructor(address _asset, address _gho, uint256 _feeBps) MockGSMBase(_asset, _gho) {
        feeBps = _feeBps;
    }

    function setFeeBps(uint256 _feeBps) external {
        feeBps = _feeBps;
    }

    /// @notice Set the consumption rate to simulate partial consumption
    /// @param _consumptionBps Consumption rate in basis points (10000 = 100%, 9900 = 99%)
    function setConsumptionBps(uint256 _consumptionBps) external {
        require(_consumptionBps <= 10000, "Invalid consumption rate");
        consumptionBps = _consumptionBps;
    }

    function buyAsset(uint256 minAmount, address receiver) external override returns (uint256, uint256) {
        // Simulate partial consumption - GSM might not burn all GHO
        uint256 actualAssetAmount = (minAmount * consumptionBps) / 10000;
        if (actualAssetAmount == 0 && minAmount > 0) actualAssetAmount = 1; // Minimum 1 wei if any input

        // Calculate GHO needed including fee (only for actual amount)
        uint256 ghoNeeded = (actualAssetAmount * 10000) / (10000 - feeBps);

        // Transfer Asset to receiver
        IERC20(asset).transfer(receiver, actualAssetAmount);
        // Pull GHO from msg.sender (only what's needed)
        IERC20(gho).transferFrom(msg.sender, address(this), ghoNeeded);

        return (actualAssetAmount, ghoNeeded);
    }

    function sellAsset(uint256 maxAmount, address receiver) external override returns (uint256, uint256) {
        // Simulate partial consumption - GSM might not take all assets
        uint256 actualSold = (maxAmount * consumptionBps) / 10000;
        if (actualSold == 0 && maxAmount > 0) actualSold = 1; // Minimum 1 wei if any input

        // Calculate GHO output after fee
        uint256 fee = (actualSold * feeBps) / 10000;
        uint256 ghoAmount = actualSold - fee;

        // Transfer GHO to receiver
        IERC20(gho).transfer(receiver, ghoAmount);
        // Pull Asset from msg.sender (only what's consumed)
        IERC20(asset).transferFrom(msg.sender, address(this), actualSold);

        return (actualSold, ghoAmount);
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
}

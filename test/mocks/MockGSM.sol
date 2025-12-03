// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockGSMBase} from "test/mocks/MockGSMBase.sol";

contract MockGSM is MockGSMBase {
    constructor(address _asset, address _gho) MockGSMBase(_asset, _gho) {}

    function buyAsset(uint256 minAmount, address receiver) external override returns (uint256, uint256) {
        uint256 amount = minAmount;
        // Transfer Asset to receiver (Router)
        IERC20(asset).transfer(receiver, amount);
        // Pull GHO from msg.sender (Router)
        IERC20(gho).transferFrom(msg.sender, address(this), amount);
        return (amount, amount);
    }

    function sellAsset(uint256 maxAmount, address receiver) external override returns (uint256, uint256) {
        uint256 amount = maxAmount;
        // Transfer GHO to receiver (Router)
        IERC20(gho).transfer(receiver, amount);
        // Pull Asset from msg.sender (Router)
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        return (amount, amount);
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

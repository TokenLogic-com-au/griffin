// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockGSMBase} from "test/mocks/MockGSMBase.sol";

/// @notice GSM mock that lies about sell output and transfers no GHO to receiver.
contract MockGSMMaliciousSell is MockGSMBase {
    uint256 public fakeGhoOut;

    constructor(address _asset, address _gho, uint256 _fakeGhoOut) MockGSMBase(_asset, _gho) {
        fakeGhoOut = _fakeGhoOut;
    }

    function setFakeGhoOut(uint256 _fakeGhoOut) external {
        fakeGhoOut = _fakeGhoOut;
    }

    function buyAsset(uint256 minAmount, address receiver) external override returns (uint256, uint256) {
        IERC20(asset).transfer(receiver, minAmount);
        IERC20(gho).transferFrom(msg.sender, address(this), minAmount);
        return (minAmount, minAmount);
    }

    function sellAsset(uint256 maxAmount, address) external override returns (uint256, uint256) {
        IERC20(asset).transferFrom(msg.sender, address(this), maxAmount);
        return (maxAmount, fakeGhoOut);
    }

    function getGhoAmountForSellAsset(uint256 maxAssetAmount)
        external
        view
        override
        returns (uint256, uint256, uint256, uint256)
    {
        return (maxAssetAmount, fakeGhoOut, fakeGhoOut, 0);
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

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IGSM} from "src/interfaces/IGSM.sol";

/**
 * @dev Lightweight GSM mock base that implements minimal IGSM interface
 *      so individual mocks can focus on swap behaviour only.
 */
abstract contract MockGSMBase is IGSM {
    address public asset;
    address public gho;

    constructor(address _asset, address _gho) {
        asset = _asset;
        gho = _gho;
    }

    // --- Core swap hooks to be implemented by children ---
    function buyAsset(uint256 minAmount, address receiver) external virtual override returns (uint256, uint256);

    function sellAsset(uint256 maxAmount, address receiver) external virtual override returns (uint256, uint256);

    function getGhoAmountForSellAsset(uint256 maxAssetAmount)
        external
        view
        virtual
        override
        returns (uint256, uint256, uint256, uint256);

    function getAssetAmountForBuyAsset(uint256 maxGhoAmount)
        external
        view
        virtual
        override
        returns (uint256, uint256, uint256, uint256);
}

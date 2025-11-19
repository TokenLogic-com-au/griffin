// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGSM {
    /**
     * @notice Buy asset with GHO
     * @param minAmount Minimum amount of asset to receive
     * @param receiver Address to receive the asset
     * @return assetAmount Amount of asset received
     * @return ghoBurned Amount of GHO burned
     */
    function buyAsset(uint256 minAmount, address receiver) external returns (uint256, uint256);

    /**
     * @notice Sell asset for GHO
     * @param maxAmount Maximum amount of asset to sell
     * @param receiver Address to receive GHO
     * @return assetSold Amount of asset sold
     * @return ghoMinted Amount of GHO minted
     */
    function sellAsset(uint256 maxAmount, address receiver) external returns (uint256, uint256);

    /**
     * @notice Get GHO amount needed to buy a specific amount of asset
     * @param minAssetAmount Minimum asset amount to buy
     * @return ghoSold Amount of GHO that would be sold
     * @return assetBought Amount of asset that would be bought
     * @return grossAmount Gross amount before fees
     * @return fee Fee amount
     */
    function getGhoAmountForBuyAsset(uint256 minAssetAmount) external view returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Get GHO amount for selling a specific amount of asset
     * @param maxAssetAmount Maximum asset amount to sell
     * @return assetSold Amount of asset that would be sold
     * @return ghoBought Amount of GHO that would be received
     * @return grossAmount Gross amount before fees
     * @return fee Fee amount
     */
    function getGhoAmountForSellAsset(uint256 maxAssetAmount) external view returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Get asset amount for buying with specific GHO amount
     * @param maxGhoAmount Maximum GHO amount to spend
     * @return ghoSold Amount of GHO that would be sold
     * @return assetBought Amount of asset that would be received
     * @return grossAmount Gross amount before fees
     * @return fee Fee amount
     */
    function getAssetAmountForBuyAsset(uint256 maxGhoAmount) external view returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Get asset amount for selling to receive specific GHO amount
     * @param minGhoAmount Minimum GHO amount to receive
     * @return assetSold Amount of asset that would be sold
     * @return ghoBought Amount of GHO that would be received
     * @return grossAmount Gross amount before fees
     * @return fee Fee amount
     */
    function getAssetAmountForSellAsset(uint256 minGhoAmount) external view returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Get available liquidity for swaps
     * @return Available liquidity amount
     */
    function getAvailableLiquidity() external view returns (uint256);

    /**
     * @notice Check if swaps are currently allowed
     * @return true if swaps are allowed
     */
    function canSwap() external view returns (bool);
}

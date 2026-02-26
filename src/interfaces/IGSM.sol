// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IGSM
 * @author Aave
 * @notice Minimal interface for GHO Stability Module functions used by GSMRouter
 */
interface IGSM {
    /**
     * @notice Buys the GSM underlying asset in exchange for selling GHO
     * @dev Use `getAssetAmountForBuyAsset` function to calculate the amount based on the GHO amount to sell
     * @param minAmount The minimum amount of the underlying asset to buy
     * @param receiver Recipient address of the underlying asset being purchased
     * @return The amount of underlying asset bought
     * @return The amount of GHO sold by the user
     */
    function buyAsset(uint256 minAmount, address receiver) external returns (uint256, uint256);

    /**
     * @notice Sells the GSM underlying asset in exchange for buying GHO
     * @dev Use `getAssetAmountForSellAsset` function to calculate the amount based on the GHO amount to buy
     * @param maxAmount The maximum amount of the underlying asset to sell
     * @param receiver Recipient address of the GHO being purchased
     * @return The amount of underlying asset sold
     * @return The amount of GHO bought by the user
     */
    function sellAsset(uint256 maxAmount, address receiver) external returns (uint256, uint256);

    /**
     * @notice Returns the amount of underlying asset, gross amount of GHO and fee result of buying assets
     * @param maxGhoAmount The maximum amount of GHO the user provides for buying underlying asset
     * @return The amount of underlying asset the user buys
     * @return The exact amount of GHO the user provides
     * @return The gross amount of GHO corresponding to the given total amount of GHO
     * @return The fee amount in GHO, charged for buying assets
     */
    function getAssetAmountForBuyAsset(uint256 maxGhoAmount) external view returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Returns the total amount of GHO, gross amount and fee result of selling assets
     * @param maxAssetAmount The maximum amount of underlying asset to sell
     * @return The exact amount of underlying asset to sell
     * @return The total amount of GHO the user buys (gross amount in GHO minus fee)
     * @return The gross amount of GHO
     * @return The fee amount in GHO, applied to the gross amount of GHO
     */
    function getGhoAmountForSellAsset(uint256 maxAssetAmount) external view returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Returns the underlying asset of the GSM
     * @return The address of the underlying asset
     */
    function UNDERLYING_ASSET() external view returns (address);

    /**
     * @notice Returns the address of the GHO token
     * @return The address of the GHO token contract
     */
    function GHO_TOKEN() external view returns (address);
}

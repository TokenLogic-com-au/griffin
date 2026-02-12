// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title IStaticAToken
 * @notice Interface for Static aToken (ERC4626 wrapper for Aave aTokens)
 */
interface IStaticAToken is IERC4626 {
    /**
     * @notice Deposit assets into the vault
     * @param assets The amount of assets to deposit
     * @param receiver The address to receive the shares
     * @return shares The amount of shares received
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * @notice Redeem shares from the vault
     * @param shares The amount of shares to redeem
     * @param receiver The address to receive the assets
     * @param owner The address of the owner of the shares
     * @return assets The amount of assets received
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}

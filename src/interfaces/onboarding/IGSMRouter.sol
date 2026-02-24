// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IGSMRouter
 * @notice Interface for GSMRouter contract
 */
interface IGSMRouter {
    /// @dev GSM not configured for the given token
    error InvalidGsm();

    /// @dev Unsupported token provided
    error InvalidToken();

    /// @dev Amount must be greater than zero
    error InvalidAmount();

    /// @dev Swap amount is lower than minimum expected amount
    error SlippageExceeded();

    /// @dev Zero address is not allowed
    error ZeroAddress();

    /**
     * @notice Emitted when a swap to GHO is completed
     * @param user The address of the user who initiated the swap
     * @param inputToken The address of the token sold (USDC/USDT)
     * @param inputAmount The amount of input tokens sold
     * @param ghoAmount The amount of GHO received
     */
    event SwapToGHO(address indexed user, address indexed inputToken, uint256 inputAmount, uint256 ghoAmount);

    /**
     * @notice Emitted when a swap from GHO is completed
     * @param user The address of the user who initiated the swap
     * @param outputToken The address of the token bought (USDC/USDT)
     * @param ghoAmount The amount of GHO sold
     * @param outputAmount The amount of output tokens received
     */
    event SwapFromGHO(address indexed user, address indexed outputToken, uint256 ghoAmount, uint256 outputAmount);

    /**
     * @notice Emitted when a swap into sGHO is completed
     * @param user The address of the user who initiated the swap
     * @param inputToken The address of the token sold (USDC/USDT/GHO)
     * @param sgho The address of the sGHO vault receiving GHO
     * @param inputAmount The amount of input tokens sold
     * @param ghoAmount The amount of GHO routed into the sGHO vault
     * @param sghoAmount The amount of sGHO shares received
     */
    event SwapTosGHO(
        address indexed user,
        address indexed inputToken,
        address indexed sgho,
        uint256 inputAmount,
        uint256 ghoAmount,
        uint256 sghoAmount
    );

    /**
     * @notice Emitted when a swap out of sGHO is completed
     * @param user The address of the user who initiated the swap
     * @param sgho The address of the sGHO vault redeemed
     * @param outputToken The address of the token received (USDC/USDT/GHO)
     * @param sghoAmount The amount of sGHO shares redeemed
     * @param ghoAmount The amount of GHO redeemed from sGHO
     * @param outputAmount The amount of output tokens received
     */
    event SwapFromsGHO(
        address indexed user,
        address indexed sgho,
        address indexed outputToken,
        uint256 sghoAmount,
        uint256 ghoAmount,
        uint256 outputAmount
    );

    /**
     * @notice Emitted when dust is returned to user due to partial GSM consumption
     * @param user The address of the user receiving the dust
     * @param token The address of the token returned
     * @param amount The amount of dust returned
     */
    event DustReturned(address indexed user, address indexed token, uint256 amount);

    /**
     * @notice Swap underlying token to GHO
     * @param token Input token address (USDC/USDT)
     * @param amount Amount of input token to swap
     * @param minGHOAmount Minimum amount of GHO to receive (slippage protection)
     * @return Amount of GHO received
     */
    function swapToGHO(address token, uint256 amount, uint256 minGHOAmount) external returns (uint256);

    /**
     * @notice Swap GHO back to underlying token
     * @param token Output token address (USDC/USDT)
     * @param ghoAmount Amount of GHO to swap
     * @param minOutputAmount Minimum amount of output token to receive (slippage protection)
     * @return Amount of output token received
     */
    function swapFromGHO(address token, uint256 ghoAmount, uint256 minOutputAmount) external returns (uint256);

    /**
     * @notice Swap USDC/USDT/GHO into sGHO shares
     * @dev For USDC/USDT input, the function routes through the configured immutable GSM first
     * @param token Input token address (USDC/USDT/GHO)
     * @param amount Amount of input token to swap
     * @param minOut Minimum amount of sGHO shares to receive (slippage protection)
     * @return Amount of sGHO shares received
     */
    function swapTosGHO(address token, uint256 amount, uint256 minOut) external returns (uint256);

    /**
     * @notice Swap sGHO shares into USDC/USDT/GHO
     * @dev For USDC/USDT output, the function routes through the configured immutable GSM
     * @param token Output token address (USDC/USDT/GHO)
     * @param amount Amount of sGHO shares to redeem and swap
     * @param minOut Minimum amount of output token to receive (slippage protection)
     * @return Amount of output tokens received
     */
    function swapFromsGHO(address token, uint256 amount, uint256 minOut) external returns (uint256);

    /**
     * @notice Rescue ERC20 token from the contract
     * @param token Address of the token to rescue
     * @param to Address to send the tokens to
     * @param amount Amount of tokens to rescue
     */
    function rescueToken(address token, address to, uint256 amount) external;

    /**
     * @notice Preview the amount of sGHO shares received for a given input amount
     * @dev This is an estimation and actual results may vary due to GSM execution and vault share price
     * @param token Input token address (USDC/USDT/GHO)
     * @param amount Amount of input token to sell
     * @return sghoAmount Expected amount of sGHO shares to receive
     * @return fee Fee amount charged by the GSM (0 for direct GHO->sGHO input)
     */
    function previewSwapTosGHO(address token, uint256 amount) external view returns (uint256, uint256);

    /**
     * @notice Preview the amount of GHO received for a given input amount
     * @dev This is an estimation and actual results may vary slightly due to interest accrual
     * @param token Input token address (USDC/USDT)
     * @param amount Amount of input token to sell
     * @return ghoAmount Expected amount of GHO to receive
     * @return fee Fee amount charged by the GSM
     */
    function previewSwapToGHO(address token, uint256 amount) external view returns (uint256, uint256);

    /**
     * @notice Preview the amount of output token received for a given GHO amount
     * @dev This is an estimation and actual results may vary slightly due to interest accrual
     * @param token Output token address (USDC/USDT)
     * @param ghoAmount Amount of GHO to sell
     * @return assetAmount Expected amount of output token to receive
     * @return fee Fee amount charged by the GSM
     */
    function previewSwapFromGHO(address token, uint256 ghoAmount) external view returns (uint256, uint256);

    /**
     * @notice Preview the amount of output token received for a given sGHO share amount
     * @dev This is an estimation and actual results may vary due to vault exchange rate and GSM execution
     * @param token Output token address (USDC/USDT/GHO)
     * @param amount Amount of sGHO shares to redeem and swap
     * @return outputAmount Expected amount of output token to receive
     * @return fee Fee amount charged by the GSM (0 for direct sGHO->GHO output)
     */
    function previewSwapFromsGHO(address token, uint256 amount) external view returns (uint256, uint256);

    /**
     * @notice Returns address of the GHO token on the deployed network
     * @return Address of the token
     */
    function GHO() external view returns (address);

    /**
     * @notice Returns address of the sGHO vault on the deployed network
     * @return Address of the vault
     */
    function sGHO() external view returns (address);

    /**
     * @notice Returns address of the immutable GSM route for USDC
     * @return Address of GSM USDC
     */
    function GSM_USDC() external view returns (address);

    /**
     * @notice Returns address of the immutable GSM route for USDT
     * @return Address of GSM USDT
     */
    function GSM_USDT() external view returns (address);
}

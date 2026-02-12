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
     * @notice Emitted when dust is returned to user due to partial GSM consumption
     * @param user The address of the user receiving the dust
     * @param token The address of the token returned
     * @param amount The amount of dust returned
     */
    event DustReturned(address indexed user, address indexed token, uint256 amount);

    /**
     * @notice Swap underlying token to GHO
     * @param gsm GSM address to route the swap through
     * @param amount Amount of input token to swap
     * @param minGHOAmount Minimum amount of GHO to receive (slippage protection)
     * @return Amount of GHO received
     */
    function swapToGHO(address gsm, uint256 amount, uint256 minGHOAmount) external returns (uint256);

    /**
     * @notice Swap GHO back to underlying token
     * @param gsm GSM address to route the swap through
     * @param ghoAmount Amount of GHO to swap
     * @param minOutputAmount Minimum amount of output token to receive (slippage protection)
     * @return Amount of output token received
     */
    function swapFromGHO(address gsm, uint256 ghoAmount, uint256 minOutputAmount) external returns (uint256);

    /**
     * @notice Rescue ERC20 token from the contract
     * @param token Address of the token to rescue
     * @param to Address to send the tokens to
     * @param amount Amount of tokens to rescue
     */
    function rescueToken(address token, address to, uint256 amount) external;

    /**
     * @notice Preview the amount of GHO received for a given input amount
     * @dev This is an estimation and actual results may vary slightly due to interest accrual
     * @param gsm GSM address to route the swap through
     * @param amount Amount of input token to sell
     * @return ghoAmount Expected amount of GHO to receive
     * @return fee Fee amount charged by the GSM
     */
    function previewSwapToGHO(address gsm, uint256 amount) external view returns (uint256 ghoAmount, uint256 fee);

    /**
     * @notice Preview the amount of output token received for a given GHO amount
     * @dev This is an estimation and actual results may vary slightly due to interest accrual
     * @param gsm GSM address to route the swap through
     * @param ghoAmount Amount of GHO to sell
     * @return assetAmount Expected amount of output token to receive
     * @return fee Fee amount charged by the GSM
     */
    function previewSwapFromGHO(address gsm, uint256 ghoAmount) external view returns (uint256 assetAmount, uint256 fee);

    /**
     * @notice Returns address of the GHO token on the deployed network
     * @return Address of the token
     */
    function GHO() external view returns (address);
}

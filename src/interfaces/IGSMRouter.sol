// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IGSMRouter
 * @notice Interface for GSMRouter contract
 */
interface IGSMRouter {
    error InvalidToken();
    error InvalidAmount();
    error SlippageExceeded();
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
     * @notice Emitted when the GSM address for USDC is updated
     * @param newGsm The new GSM USDC address
     */
    event GsmUSDCUpdated(address indexed newGsm);

    /**
     * @notice Emitted when the GSM address for USDT is updated
     * @param newGsm The new GSM USDT address
     */
    event GsmUSDTUpdated(address indexed newGsm);

    /**
     * @notice Updates the GSM address for USDC
     * @dev Only callable by owner
     * @param _gsmUSDC New GSM USDC address
     */
    function setGsmUSDC(address _gsmUSDC) external;

    /**
     * @notice Updates the GSM address for USDT
     * @dev Only callable by owner
     * @param _gsmUSDT New GSM USDT address
     */
    function setGsmUSDT(address _gsmUSDT) external;

    /**
     * @notice Swap USDC or USDT to GHO
     * @param token Input token address (USDC or USDT)
     * @param amount Amount of input token to swap
     * @param minGHOAmount Minimum amount of GHO to receive (slippage protection)
     * @return Amount of GHO received
     */
    function swapToGHO(address token, uint256 amount, uint256 minGHOAmount) external returns (uint256);

    /**
     * @notice Swap GHO back to USDC or USDT
     * @param token Output token address (USDC or USDT)
     * @param ghoAmount Amount of GHO to swap
     * @param minOutputAmount Minimum amount of output token to receive (slippage protection)
     * @return Amount of output token received
     */
    function swapFromGHO(address token, uint256 ghoAmount, uint256 minOutputAmount) external returns (uint256);

    /**
     * @notice Preview the amount of GHO received for a given input amount
     * @dev This is an estimation and actual results may vary slightly due to interest accrual
     * @param token Input token address (USDC or USDT)
     * @param amount Amount of input token to sell
     * @return ghoAmount Expected amount of GHO to receive
     * @return fee Fee amount charged by the GSM
     */
    function previewSwapToGHO(address token, uint256 amount) external view returns (uint256 ghoAmount, uint256 fee);

    /**
     * @notice Preview the amount of output token received for a given GHO amount
     * @dev This is an estimation and actual results may vary slightly due to interest accrual
     * @param token Output token address (USDC or USDT)
     * @param ghoAmount Amount of GHO to sell
     * @return assetAmount Expected amount of output token to receive
     * @return fee Fee amount charged by the GSM
     */
    function previewSwapFromGHO(address token, uint256 ghoAmount)
        external
        view
        returns (uint256 assetAmount, uint256 fee);
}

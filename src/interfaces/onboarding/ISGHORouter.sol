// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title ISGHORouter
 * @notice Interface for routing USDC/USDT/GHO into and out of sGHO
 */
interface ISGHORouter {
    /// @dev Zero address is not allowed.
    error ZeroAddress();

    /// @dev Token is not supported by this router.
    error InvalidToken();

    /// @dev Amount or shares must be greater than zero.
    error InvalidAmount();

    /// @dev Swap/redeem output is lower than user minimum.
    error SlippageExceeded();

    /// @dev GSM, router, or sGHO configuration is invalid.
    error InvalidConfiguration();

    /**
     * @notice Emitted when user deposits into sGHO through the helper.
     * @param user User receiving sGHO shares.
     * @param inputToken Token provided by the user (USDC/USDT/GHO).
     * @param inputAmount Amount of input token supplied by the user.
     * @param ghoAmount Amount of GHO deposited into sGHO.
     * @param sharesReceived Amount of sGHO shares minted to the user.
     */
    event Deposited(
        address indexed user, address indexed inputToken, uint256 inputAmount, uint256 ghoAmount, uint256 sharesReceived
    );

    /**
     * @notice Emitted when user redeems sGHO shares through the helper.
     * @param user User redeeming shares.
     * @param outputToken Token requested by the user (USDC/USDT/GHO).
     * @param sharesRedeemed Amount of sGHO shares redeemed.
     * @param outputAmount Amount of output token transferred to the user.
     */
    event Redeemed(address indexed user, address indexed outputToken, uint256 sharesRedeemed, uint256 outputAmount);

    /**
     * @notice Emitted when residual token dust is returned to user.
     * @param user User receiving dust.
     * @param token Token returned as dust.
     * @param amount Amount of dust returned.
     */
    event DustReturned(address indexed user, address indexed token, uint256 amount);

    /**
     * @notice Deposit USDC, USDT, or GHO and receive sGHO shares.
     * @dev USDC/USDT are routed through GSMRouter into GHO first.
     * @param token Input token (USDC/USDT/GHO).
     * @param amount Input token amount.
     * @param minOutputAmount Minimum GHO output expected from the swap leg.
     * @return shares Amount of sGHO shares minted to caller.
     */
    function deposit(address token, uint256 amount, uint256 minOutputAmount) external returns (uint256 shares);

    /**
     * @notice Redeem sGHO shares for USDC, USDT, or GHO.
     * @dev For USDC/USDT output, shares are redeemed to GHO first then routed via GSMRouter.
     * @param shares Amount of sGHO shares to redeem.
     * @param token Output token requested (USDC/USDT/GHO).
     * @param minOutputAmount Minimum output token amount expected.
     * @return amountOut Amount of output token transferred to caller.
     */
    function redeem(uint256 shares, address token, uint256 minOutputAmount) external returns (uint256 amountOut);

    function GSM_ROUTER() external view returns (address);
    function SGHO() external view returns (address);
    function GHO() external view returns (address);
    function USDC() external view returns (address);
    function USDT() external view returns (address);
    function GSM_USDC() external view returns (address);
    function GSM_USDT() external view returns (address);
}

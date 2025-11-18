// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPool {
    struct ReserveData {
        // Configuration
        uint256 configuration;
        // Liquidity index in ray
        uint128 liquidityIndex;
        // Current supply rate in ray
        uint128 currentLiquidityRate;
        // Variable borrow index in ray
        uint128 variableBorrowIndex;
        // Current variable borrow rate in ray
        uint128 currentVariableBorrowRate;
        // Current stable borrow rate in ray
        uint128 currentStableBorrowRate;
        // Timestamp of last update
        uint40 lastUpdateTimestamp;
        // Id of the reserve
        uint16 id;
        // aToken address
        address aTokenAddress;
        // stableDebtToken address
        address stableDebtTokenAddress;
        // variableDebtToken address
        address variableDebtTokenAddress;
        // Interest rate strategy address
        address interestRateStrategyAddress;
        // Current treasury balance, scaled
        uint128 accruedToTreasury;
        // Outstanding unbacked aTokens minted through the bridging feature
        uint128 unbacked;
        // Outstanding debt borrowed against this asset in isolation mode
        uint128 isolationModeTotalDebt;
    }

    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    function getReserveData(address asset) external view returns (ReserveData memory);
}

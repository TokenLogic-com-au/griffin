// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IGhoRouter {
    error InvalidAmount();
    error SlippageExceeded();
    error ZeroAddress();

    function GHO() external view returns (address);

    function sGHO() external view returns (address);
}

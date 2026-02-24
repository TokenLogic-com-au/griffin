// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @notice sGHO-like vault mock with configurable exchange rate.
 * @dev shares = assets * 1e18 / exchangeRate; assets = shares * exchangeRate / 1e18
 */
contract MockSGHOWithRate is ERC20 {
    using SafeERC20 for IERC20;

    uint256 public constant RATE_PRECISION = 1e18;

    IERC20 public immutable GHO;
    uint256 public exchangeRate = RATE_PRECISION;

    constructor(address ghoToken) ERC20("Savings GHO", "sGHO") {
        GHO = IERC20(ghoToken);
    }

    function setExchangeRate(uint256 newExchangeRate) external {
        require(newExchangeRate > 0, "INVALID_RATE");
        exchangeRate = newExchangeRate;
    }

    function asset() external view returns (address) {
        return address(GHO);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = (assets * RATE_PRECISION) / exchangeRate;
        GHO.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        if (msg.sender != owner) _spendAllowance(owner, msg.sender, shares);

        _burn(owner, shares);
        assets = (shares * exchangeRate) / RATE_PRECISION;
        GHO.safeTransfer(receiver, assets);
    }

    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        return (assets * RATE_PRECISION) / exchangeRate;
    }

    function previewRedeem(uint256 shares) external view returns (uint256 assets) {
        return (shares * exchangeRate) / RATE_PRECISION;
    }
}

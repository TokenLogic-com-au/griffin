// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @notice Minimal sGHO-like vault mock (1:1 assets/shares) for router testing.
 */
contract MockSGHO is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public immutable gho;

    constructor(address ghoToken) ERC20("Savings GHO", "sGHO") {
        gho = IERC20(ghoToken);
    }

    function asset() external view returns (address) {
        return address(gho);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = assets;
        gho.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        if (msg.sender != owner) _spendAllowance(owner, msg.sender, shares);

        _burn(owner, shares);
        assets = shares;
        gho.safeTransfer(receiver, assets);
    }
}

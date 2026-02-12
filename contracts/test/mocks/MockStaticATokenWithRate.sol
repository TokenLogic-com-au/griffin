// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IStaticAToken} from "src/interfaces/IStaticAToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice StaticAToken mock with configurable exchange rate (simulates interest accrual)
contract MockStaticATokenWithRate is IStaticAToken {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public override totalSupply;
    address public underlying;

    // Exchange rate: shares = assets * RATE_PRECISION / exchangeRate
    // If exchangeRate > RATE_PRECISION, 1 share is worth more than 1 asset (interest accrued)
    uint256 public exchangeRate;
    uint256 public constant RATE_PRECISION = 1e18;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, address _underlying) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        underlying = _underlying;
        exchangeRate = RATE_PRECISION; // Start at 1:1
    }

    function setExchangeRate(uint256 _exchangeRate) external {
        exchangeRate = _exchangeRate;
    }

    function _mint(address to, uint256 amount) internal {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function deposit(uint256 assets, address receiver) external override returns (uint256) {
        IERC20(underlying).transferFrom(msg.sender, address(this), assets);
        uint256 shares = (assets * RATE_PRECISION) / exchangeRate;
        _mint(receiver, shares);
        return shares;
    }

    function redeem(uint256 shares, address receiver, address owner) external override returns (uint256) {
        burn(owner, shares);
        uint256 assets = (shares * exchangeRate) / RATE_PRECISION;
        IERC20(underlying).transfer(receiver, assets);
        return assets;
    }

    function previewDeposit(uint256 assets) external view override returns (uint256) {
        return (assets * RATE_PRECISION) / exchangeRate;
    }

    function previewRedeem(uint256 shares) external view override returns (uint256) {
        return (shares * exchangeRate) / RATE_PRECISION;
    }

    // ERC4626 interface stubs
    function asset() external view override returns (address) {
        return underlying;
    }

    function totalAssets() external view override returns (uint256) {
        return (totalSupply * exchangeRate) / RATE_PRECISION;
    }

    function convertToShares(uint256 assets) external view override returns (uint256) {
        return (assets * RATE_PRECISION) / exchangeRate;
    }

    function convertToAssets(uint256 shares) external view override returns (uint256) {
        return (shares * exchangeRate) / RATE_PRECISION;
    }

    function maxDeposit(address) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function previewMint(uint256 shares) external view override returns (uint256) {
        return (shares * exchangeRate) / RATE_PRECISION;
    }

    function mint(uint256 shares, address receiver) external override returns (uint256) {
        uint256 assets = (shares * exchangeRate) / RATE_PRECISION;
        IERC20(underlying).transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        return assets;
    }

    function maxWithdraw(address) external pure override returns (uint256) {
        return type(uint256).max;
    }

    function previewWithdraw(uint256 assets) external view override returns (uint256) {
        return (assets * RATE_PRECISION) / exchangeRate;
    }

    function withdraw(uint256 assets, address receiver, address owner) external override returns (uint256) {
        uint256 shares = (assets * RATE_PRECISION) / exchangeRate;
        burn(owner, shares);
        IERC20(underlying).transfer(receiver, assets);
        return shares;
    }

    function maxRedeem(address) external pure override returns (uint256) {
        return type(uint256).max;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IStaticAToken} from "src/interfaces/IStaticAToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockStaticAToken is IStaticAToken {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public override totalSupply;
    address public underlying;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, address _underlying) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        underlying = _underlying;
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
        // Pull underlying
        IERC20(underlying).transferFrom(msg.sender, address(this), assets);
        // Mint shares (1:1)
        _mint(receiver, assets);
        return assets;
    }

    function redeem(uint256 shares, address receiver, address owner) external override returns (uint256) {
        // Burn shares
        burn(owner, shares);
        // Send underlying (1:1)
        IERC20(underlying).transfer(receiver, shares);
        return shares;
    }

    function previewDeposit(uint256 assets) external pure override returns (uint256) {
        return assets;
    }

    function previewRedeem(uint256 shares) external pure override returns (uint256) {
        return shares;
    }

    // ERC4626 interface stubs - required by interface but not used in router tests
    function asset() external view override returns (address) {
        return address(0);
    }

    function totalAssets() external view override returns (uint256) {
        return 0;
    }

    function convertToShares(uint256 assets) external view override returns (uint256) {
        return assets;
    }

    function convertToAssets(uint256 shares) external view override returns (uint256) {
        return shares;
    }

    function maxDeposit(address) external view override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) external view override returns (uint256) {
        return type(uint256).max;
    }

    function previewMint(uint256 shares) external view override returns (uint256) {
        return shares;
    }

    function mint(uint256 shares, address receiver) external override returns (uint256) {
        _mint(receiver, shares);
        return shares;
    }

    function maxWithdraw(address) external view override returns (uint256) {
        return type(uint256).max;
    }

    function previewWithdraw(uint256 assets) external view override returns (uint256) {
        return assets;
    }

    function withdraw(uint256 assets, address, address owner) external override returns (uint256) {
        burn(owner, assets);
        return assets;
    }

    function maxRedeem(address) external view override returns (uint256) {
        return type(uint256).max;
    }
}

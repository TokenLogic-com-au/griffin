// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @notice Copy of Aave gho-origin sGho (commit f4686827), adapted to non-upgradeable OZ.
 * @dev Constructor replaces initialize for local test deployment convenience.
 */
contract sGHO is ERC4626, ERC20Permit, AccessControl, Pausable {
    using Math for uint256;
    using SafeCast for uint256;

    error MaxRateExceeded();
    error ZeroAddressNotAllowed();

    event TargetRateUpdated(uint256 newRate);
    event ExchangeRateUpdated(uint256 timestamp, uint256 currentRate);
    event SupplyCapUpdated(uint256 newSupplyCap);

    struct SignatureParams {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    uint176 private constant RAY = 1e27;

    uint16 public constant MAX_SAFE_RATE = 50_00;
    bytes32 public constant PAUSE_GUARDIAN_ROLE = keccak256("PAUSE_GUARDIAN_ROLE");
    bytes32 public constant TOKEN_RESCUER_ROLE = keccak256("TOKEN_RESCUER_ROLE");
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");

    uint176 private _yieldIndex;
    uint64 private _lastUpdate;
    uint16 private _targetRate;
    uint160 private _supplyCap;
    uint96 private _ratePerSecond;

    constructor(address gho, uint160 initialSupplyCap, address owner)
        ERC20("sGho", "sGho")
        ERC4626(IERC20(gho))
        ERC20Permit("sGho")
    {
        if (gho == address(0) || owner == address(0)) revert ZeroAddressNotAllowed();

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(PAUSE_GUARDIAN_ROLE, owner);

        _supplyCap = initialSupplyCap;
        _yieldIndex = RAY;
        _lastUpdate = uint64(block.timestamp);
        _ratePerSecond = 0;
        _targetRate = 0;
    }

    function depositWithPermit(uint256 assets, address receiver, uint256 deadline, SignatureParams memory sig)
        external
        returns (uint256)
    {
        try IERC20Permit(asset()).permit(_msgSender(), address(this), assets, deadline, sig.v, sig.r, sig.s) {} catch {}
        return deposit(assets, receiver);
    }

    function pause() external onlyRole(PAUSE_GUARDIAN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSE_GUARDIAN_ROLE) {
        _unpause();
    }

    function setTargetRate(uint16 newRate) external onlyRole(YIELD_MANAGER_ROLE) {
        if (newRate > MAX_SAFE_RATE) revert MaxRateExceeded();

        _updateYieldIndex();
        _targetRate = newRate;

        uint256 annualRateRay = (uint256(newRate) * RAY) / 10000;
        _ratePerSecond = (annualRateRay / 365 days).toUint96();

        emit TargetRateUpdated(newRate);
    }

    function setSupplyCap(uint160 newSupplyCap) external onlyRole(YIELD_MANAGER_ROLE) {
        _supplyCap = newSupplyCap;
        emit SupplyCapUpdated(newSupplyCap);
    }

    function decimals() public pure override(ERC20, ERC4626) returns (uint8) {
        return 18;
    }

    function lastUpdate() external view returns (uint64) {
        return _lastUpdate;
    }

    function targetRate() external view returns (uint16) {
        return _targetRate;
    }

    function GHO() external view returns (address) {
        return asset();
    }

    function maxWithdraw(address owner) public view override returns (uint256) {
        if (paused()) {
            return 0;
        }

        uint256 ghoBalance = IERC20(asset()).balanceOf(address(this));
        uint256 maxWithdrawAssets = super.maxWithdraw(owner);
        return maxWithdrawAssets < ghoBalance ? maxWithdrawAssets : ghoBalance;
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        if (paused()) {
            return 0;
        }

        uint256 ghoBalance = IERC20(asset()).balanceOf(address(this));
        uint256 maxRedeemShares = super.maxRedeem(owner);
        uint256 sharesForBalance = convertToShares(ghoBalance);
        return maxRedeemShares < sharesForBalance ? maxRedeemShares : sharesForBalance;
    }

    function maxDeposit(address) public view override returns (uint256) {
        if (paused()) {
            return 0;
        }

        uint256 currentAssets = totalAssets();
        return currentAssets >= _supplyCap ? 0 : _supplyCap - currentAssets;
    }

    function maxMint(address receiver) public view override returns (uint256) {
        return convertToShares(maxDeposit(receiver));
    }

    function supplyCap() external view returns (uint160) {
        return _supplyCap;
    }

    function totalAssets() public view override returns (uint256) {
        return _convertToAssets(totalSupply(), Math.Rounding.Floor);
    }

    function ratePerSecond() external view returns (uint96) {
        return _ratePerSecond;
    }

    function yieldIndex() external view returns (uint176) {
        return _yieldIndex;
    }

    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        _updateYieldIndex();
        super._update(from, to, value);
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        uint256 currentYieldIndex = _getCurrentYieldIndex();
        if (currentYieldIndex == 0) return 0;
        return assets.mulDiv(RAY, currentYieldIndex, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        uint256 currentYieldIndex = _getCurrentYieldIndex();
        return shares.mulDiv(currentYieldIndex, RAY, rounding);
    }

    function _getCurrentYieldIndex() internal view returns (uint176) {
        if (_ratePerSecond == 0) return _yieldIndex;

        uint256 timeSinceLastUpdate = block.timestamp - _lastUpdate;
        if (timeSinceLastUpdate == 0) return _yieldIndex;

        uint256 accumulatedRate = uint256(_ratePerSecond) * timeSinceLastUpdate;
        uint256 growthFactor = RAY + accumulatedRate;

        return ((uint256(_yieldIndex) * growthFactor) / RAY).toUint176();
    }

    function _updateYieldIndex() internal {
        if (_lastUpdate != block.timestamp) {
            uint176 newYieldIndex = _getCurrentYieldIndex();
            _yieldIndex = newYieldIndex;
            _lastUpdate = uint64(block.timestamp);
            emit ExchangeRateUpdated(block.timestamp, newYieldIndex);
        }
    }
}

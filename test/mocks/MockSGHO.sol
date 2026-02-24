// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @notice Lightweight sGho mock
 * @dev Keeps constructor simplicity for tests while exposing IsGho-like methods.
 */
contract MockSGHO is ERC20 {
    using SafeERC20 for IERC20;

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

    uint176 internal constant RAY = 1e27;
    uint16 public constant MAX_SAFE_RATE = 50_00;
    bytes32 public constant PAUSE_GUARDIAN_ROLE = keccak256("PAUSE_GUARDIAN_ROLE");
    bytes32 public constant TOKEN_RESCUER_ROLE = keccak256("TOKEN_RESCUER_ROLE");
    bytes32 public constant YIELD_MANAGER_ROLE = keccak256("YIELD_MANAGER_ROLE");

    IERC20 public immutable gho;
    uint176 internal _yieldIndex;
    uint64 internal _lastUpdate;
    uint16 internal _targetRate;
    uint160 internal _supplyCap;
    uint96 internal _ratePerSecond;
    bool internal _paused;

    constructor(address ghoToken) ERC20("sGho", "sGho") {
        if (ghoToken == address(0)) revert ZeroAddressNotAllowed();
        gho = IERC20(ghoToken);
        _yieldIndex = RAY;
        _lastUpdate = uint64(block.timestamp);
        _supplyCap = type(uint160).max;
    }

    function asset() external view returns (address) {
        return address(gho);
    }

    function GHO() external view returns (address) {
        return address(gho);
    }

    function lastUpdate() external view returns (uint64) {
        return _lastUpdate;
    }

    function targetRate() external view returns (uint16) {
        return _targetRate;
    }

    function supplyCap() external view returns (uint160) {
        return _supplyCap;
    }

    function ratePerSecond() external view returns (uint96) {
        return _ratePerSecond;
    }

    function yieldIndex() external view returns (uint176) {
        return _yieldIndex;
    }

    function paused() external view returns (bool) {
        return _paused;
    }

    function pause() external {
        _paused = true;
    }

    function unpause() external {
        _paused = false;
    }

    function setTargetRate(uint16 newRate) external {
        if (newRate > MAX_SAFE_RATE) revert MaxRateExceeded();
        _updateYieldIndex();
        _targetRate = newRate;

        uint256 annualRateRay = (uint256(newRate) * RAY) / 10_000;
        _ratePerSecond = uint96(annualRateRay / 365 days);

        emit TargetRateUpdated(newRate);
    }

    function setSupplyCap(uint160 newSupplyCap) external {
        _supplyCap = newSupplyCap;
        emit SupplyCapUpdated(newSupplyCap);
    }

    function totalAssets() public view returns (uint256) {
        return _convertToAssets(totalSupply(), _getCurrentYieldIndex());
    }

    function maxDeposit(address) public view returns (uint256) {
        if (_paused) return 0;
        uint256 currentAssets = totalAssets();
        return currentAssets >= _supplyCap ? 0 : _supplyCap - currentAssets;
    }

    function maxMint(address receiver) external view returns (uint256) {
        return _convertToShares(maxDeposit(receiver), _getCurrentYieldIndex());
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        if (_paused) return 0;
        uint256 maxWithdrawAssets = _convertToAssets(balanceOf(owner), _getCurrentYieldIndex());
        uint256 ghoBalance = gho.balanceOf(address(this));
        return maxWithdrawAssets < ghoBalance ? maxWithdrawAssets : ghoBalance;
    }

    function maxRedeem(address owner) external view returns (uint256) {
        if (_paused) return 0;
        uint256 maxRedeemShares = balanceOf(owner);
        uint256 sharesForBalance = _convertToShares(gho.balanceOf(address(this)), _getCurrentYieldIndex());
        return maxRedeemShares < sharesForBalance ? maxRedeemShares : sharesForBalance;
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        return _convertToShares(assets, _getCurrentYieldIndex());
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares, _getCurrentYieldIndex());
    }

    function depositWithPermit(
        uint256 assets,
        address receiver,
        uint256,
        SignatureParams memory
    )
        external
        returns (uint256)
    {
        return _deposit(assets, receiver);
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        return _deposit(assets, receiver);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        return _redeem(shares, receiver, owner);
    }

    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        return _convertToShares(assets, _getCurrentYieldIndex());
    }

    function previewRedeem(uint256 shares) external view returns (uint256 assets) {
        return _convertToAssets(shares, _getCurrentYieldIndex());
    }

    function _deposit(uint256 assets, address receiver) internal returns (uint256 shares) {
        require(!_paused, "PAUSED");
        _updateYieldIndex();
        require(assets <= maxDeposit(receiver), "SUPPLY_CAP_EXCEEDED");

        shares = _convertToShares(assets, _yieldIndex);
        gho.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
    }

    function _redeem(uint256 shares, address receiver, address owner) internal returns (uint256 assets) {
        require(!_paused, "PAUSED");
        _updateYieldIndex();
        if (msg.sender != owner) _spendAllowance(owner, msg.sender, shares);

        _burn(owner, shares);
        assets = _convertToAssets(shares, _yieldIndex);
        gho.safeTransfer(receiver, assets);
    }

    function _updateYieldIndex() internal {
        if (_lastUpdate != block.timestamp) {
            uint176 newYieldIndex = _getCurrentYieldIndex();
            _yieldIndex = newYieldIndex;
            _lastUpdate = uint64(block.timestamp);
            emit ExchangeRateUpdated(block.timestamp, newYieldIndex);
        }
    }

    function _getCurrentYieldIndex() internal view returns (uint176) {
        if (_ratePerSecond == 0) return _yieldIndex;

        uint256 timeSinceLastUpdate = block.timestamp - _lastUpdate;
        if (timeSinceLastUpdate == 0) return _yieldIndex;

        uint256 accumulatedRate = uint256(_ratePerSecond) * timeSinceLastUpdate;
        uint256 growthFactor = RAY + accumulatedRate;

        return uint176((uint256(_yieldIndex) * growthFactor) / RAY);
    }

    function _convertToShares(uint256 assets, uint256 currentYieldIndex) internal pure returns (uint256) {
        if (currentYieldIndex == 0) return 0;
        return (assets * RAY) / currentYieldIndex;
    }

    function _convertToAssets(uint256 shares, uint256 currentYieldIndex) internal pure returns (uint256) {
        return (shares * currentYieldIndex) / RAY;
    }

    function _update(address from, address to, uint256 value) internal override {
        require(!_paused, "PAUSED");
        _updateYieldIndex();
        super._update(from, to, value);
    }
}

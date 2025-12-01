// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IGSM} from "src/interfaces/IGSM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Lightweight GSM mock base that stubs all IGSM/IAccessControl/IGhoFacilitator
 *      requirements so individual mocks can focus on swap behaviour only.
 */
abstract contract MockGSMBase is IGSM {
    address public asset;
    address public gho;

    address internal ghoReserve;
    address internal ghoTreasury;
    address internal feeStrategy;
    uint128 internal exposureCap;
    uint256 internal limitCap = type(uint256).max;
    bool internal frozen;
    bool internal seized;

    mapping(address => uint256) internal _nonces;

    constructor(address _asset, address _gho) {
        asset = _asset;
        gho = _gho;
        ghoReserve = _gho;
    }

    // --- Core swap hooks to be implemented by children ---
    function buyAsset(uint256 minAmount, address receiver) external virtual override returns (uint256, uint256);

    function sellAsset(uint256 maxAmount, address receiver) external virtual override returns (uint256, uint256);

    function getGhoAmountForBuyAsset(uint256 minAssetAmount)
        external
        view
        virtual
        override
        returns (uint256, uint256, uint256, uint256);

    function getGhoAmountForSellAsset(uint256 maxAssetAmount)
        external
        view
        virtual
        override
        returns (uint256, uint256, uint256, uint256);

    function getAssetAmountForBuyAsset(uint256 maxGhoAmount)
        external
        view
        virtual
        override
        returns (uint256, uint256, uint256, uint256);

    function getAssetAmountForSellAsset(uint256 minGhoAmount)
        external
        view
        virtual
        override
        returns (uint256, uint256, uint256, uint256);

    function getAvailableLiquidity() external view virtual override returns (uint256) {
        return type(uint256).max;
    }

    function canSwap() external view virtual override returns (bool) {
        return !frozen;
    }

    // --- Signature helpers ---
    function BUY_ASSET_WITH_SIG_TYPEHASH() external pure override returns (bytes32) {
        return keccak256("MOCK_BUY_ASSET_WITH_SIG");
    }

    function SELL_ASSET_WITH_SIG_TYPEHASH() external pure override returns (bytes32) {
        return keccak256("MOCK_SELL_ASSET_WITH_SIG");
    }

    function DOMAIN_SEPARATOR() external pure override returns (bytes32) {
        return bytes32(0);
    }

    function nonces(address user) external view override returns (uint256) {
        return _nonces[user];
    }

    function buyAssetWithSig(address originator, uint256 minAmount, address receiver, uint256, bytes calldata)
        external
        override
        returns (uint256, uint256)
    {
        _nonces[originator] += 1;
        return this.buyAsset(minAmount, receiver);
    }

    function sellAssetWithSig(address originator, uint256 maxAmount, address receiver, uint256, bytes calldata)
        external
        override
        returns (uint256, uint256)
    {
        _nonces[originator] += 1;
        return this.sellAsset(maxAmount, receiver);
    }

    // --- AccessControl stubs ---
    function CONFIGURATOR_ROLE() public pure override returns (bytes32) {
        return keccak256("CONFIGURATOR_ROLE");
    }

    function TOKEN_RESCUER_ROLE() public pure override returns (bytes32) {
        return keccak256("TOKEN_RESCUER_ROLE");
    }

    function SWAP_FREEZER_ROLE() public pure override returns (bytes32) {
        return keccak256("SWAP_FREEZER_ROLE");
    }

    function LIQUIDATOR_ROLE() public pure override returns (bytes32) {
        return keccak256("LIQUIDATOR_ROLE");
    }

    function getRoleAdmin(bytes32) external pure override returns (bytes32) {
        return bytes32(0);
    }

    function grantRole(bytes32, address) external pure override {}

    function hasRole(bytes32, address) external pure override returns (bool) {
        return true;
    }

    function renounceRole(bytes32, address) external pure override {}

    function revokeRole(bytes32, address) external pure override {}

    // --- Facilitator administration ---
    function distributeFeesToTreasury() external override {}

    function updateGhoTreasury(address newGhoTreasury) external override {
        ghoTreasury = newGhoTreasury;
    }

    function getGhoTreasury() external view override returns (address) {
        return ghoTreasury;
    }

    // --- GSM configuration ---
    function updateFeeStrategy(address _feeStrategy) external override {
        feeStrategy = _feeStrategy;
    }

    function updateExposureCap(uint128 _exposureCap) external override {
        exposureCap = _exposureCap;
    }

    function updateGhoReserve(address newGhoReserve) external override {
        ghoReserve = newGhoReserve;
    }

    function setSwapFreeze(bool enable) external override {
        frozen = enable;
    }

    function seize() external override returns (uint256) {
        seized = true;
        return 0;
    }

    function burnAfterSeize(uint256) external override returns (uint256) {
        return 0;
    }

    function rescueTokens(address token, address to, uint256 amount) external override {
        IERC20(token).transfer(to, amount);
    }

    // --- Views ---
    function getAccruedFees() external pure override returns (uint256) {
        return 0;
    }

    function getAvailableUnderlyingExposure() external view override returns (uint256) {
        return type(uint256).max;
    }

    function getExposureCap() external view override returns (uint128) {
        return exposureCap;
    }

    function getFeeStrategy() external view override returns (address) {
        return feeStrategy;
    }

    function getGhoReserve() external view override returns (address) {
        return ghoReserve;
    }

    function getIsFrozen() external view override returns (bool) {
        return frozen;
    }

    function getIsSeized() external view override returns (bool) {
        return seized;
    }

    function getUsed() external view override returns (uint256) {
        return 0;
    }

    function getLimit() external view override returns (uint256) {
        return limitCap;
    }

    function GHO_TOKEN() external view override returns (address) {
        return gho;
    }

    function UNDERLYING_ASSET() external view override returns (address) {
        return asset;
    }

    function PRICE_STRATEGY() external pure override returns (address) {
        return address(0);
    }

    function GSM_REVISION() external pure override returns (uint256) {
        return 1;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import { IXERC20 } from "./interface/IXERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManagedUpgradeable } from
    "@openzeppelin-contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ERC20PermitUpgradeable } from
    "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

contract XERC20PufferVault is IXERC20, AccessManagedUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable {
    /**
     * @notice The duration it takes for the limits to fully replenish
     */
    uint256 private constant _DURATION = 1 days;

    /**
     * @notice The address of the lockbox contract
     */
    address public lockbox;

    /**
     * @notice Maps bridge address to bridge configurations
     */
    mapping(address => Bridge) public bridges;

    constructor() {
        _disableInitializers();
    }

    function initialize(address accessManager) public initializer {
        __AccessManaged_init(accessManager);
        __ERC20_init("xPufETH", "xPufETH");
        __ERC20Permit_init("xPufETH");
    }

    /**
     * @notice Mints tokens for a user
     * @dev Can only be called by a bridge
     * @param user The address of the user who needs tokens minted
     * @param amount The amount of tokens being minted
     */
    function mint(address user, uint256 amount) public {
        _mintWithCaller(msg.sender, user, amount);
    }

    /**
     * @notice Burns tokens for a user
     * @dev Can only be called by a bridge
     * @param user The address of the user who needs tokens burned
     * @param amount The amount of tokens being burned
     */
    function burn(address user, uint256 amount) public {
        if (msg.sender != user) {
            _spendAllowance(user, msg.sender, amount);
        }

        _burnWithCaller(msg.sender, user, amount);
    }

    /**
     * @notice Sets the lockbox address
     *
     * @param lockboxAddress The address of the lockbox
     */
    function setLockbox(address lockboxAddress) public restricted {
        lockbox = lockboxAddress;

        emit LockboxSet(lockboxAddress);
    }

    /**
     * @notice Updates the limits of any bridge
     * @dev Can only be called by the owner
     * @param mintingLimit The updated minting limit we are setting to the bridge
     * @param burningLimit The updated burning limit we are setting to the bridge
     * @param bridge The address of the bridge we are setting the limits too
     */
    function setLimits(address bridge, uint256 mintingLimit, uint256 burningLimit) external restricted {
        if (mintingLimit > (type(uint256).max / 2) || burningLimit > (type(uint256).max / 2)) {
            revert IXERC20_LimitsTooHigh();
        }

        _changeMinterLimit(bridge, mintingLimit);
        _changeBurnerLimit(bridge, burningLimit);
        emit BridgeLimitsSet(mintingLimit, burningLimit, bridge);
    }

    /**
     * @notice Returns the max limit of a bridge
     *
     * @param bridge the bridge we are viewing the limits of
     * @return limit The limit the bridge has
     */
    function mintingMaxLimitOf(address bridge) public view returns (uint256 limit) {
        limit = bridges[bridge].minterParams.maxLimit;
    }

    /**
     * @notice Returns the max limit of a bridge
     *
     * @param bridge the bridge we are viewing the limits of
     * @return limit The limit the bridge has
     */
    function burningMaxLimitOf(address bridge) public view returns (uint256 limit) {
        limit = bridges[bridge].burnerParams.maxLimit;
    }

    /**
     * @notice Returns the current limit of a bridge
     *
     * @param bridge the bridge we are viewing the limits of
     * @return limit The limit the bridge has
     */
    function mintingCurrentLimitOf(address bridge) public view returns (uint256 limit) {
        limit = _getCurrentLimit(
            bridges[bridge].minterParams.currentLimit,
            bridges[bridge].minterParams.maxLimit,
            bridges[bridge].minterParams.timestamp,
            bridges[bridge].minterParams.ratePerSecond
        );
    }

    /**
     * @notice Returns the current limit of a bridge
     *
     * @param bridge the bridge we are viewing the limits of
     * @return limit The limit the bridge has
     */
    function burningCurrentLimitOf(address bridge) public view returns (uint256 limit) {
        limit = _getCurrentLimit(
            bridges[bridge].burnerParams.currentLimit,
            bridges[bridge].burnerParams.maxLimit,
            bridges[bridge].burnerParams.timestamp,
            bridges[bridge].burnerParams.ratePerSecond
        );
    }

    /**
     * @notice Uses the limit of any bridge
     * @param bridge The address of the bridge who is being changed
     * @param change The change in the limit
     */
    function _useMinterLimits(address bridge, uint256 change) internal {
        uint256 currentLimit = mintingCurrentLimitOf(bridge);
        bridges[bridge].minterParams.timestamp = block.timestamp;
        bridges[bridge].minterParams.currentLimit = currentLimit - change;
    }

    /**
     * @notice Uses the limit of any bridge
     * @param bridge The address of the bridge who is being changed
     * @param change The change in the limit
     */
    function _useBurnerLimits(address bridge, uint256 change) internal {
        uint256 currentLimit = burningCurrentLimitOf(bridge);
        bridges[bridge].burnerParams.timestamp = block.timestamp;
        bridges[bridge].burnerParams.currentLimit = currentLimit - change;
    }

    /**
     * @notice Updates the limit of any bridge
     * @dev Can only be called by the owner
     * @param bridge The address of the bridge we are setting the limit too
     * @param limit The updated limit we are setting to the bridge
     */
    function _changeMinterLimit(address bridge, uint256 limit) internal {
        uint256 oldLimit = bridges[bridge].minterParams.maxLimit;
        uint256 currentLimit = mintingCurrentLimitOf(bridge);
        bridges[bridge].minterParams.maxLimit = limit;

        bridges[bridge].minterParams.currentLimit = _calculateNewCurrentLimit(limit, oldLimit, currentLimit);

        bridges[bridge].minterParams.ratePerSecond = limit / _DURATION;
        bridges[bridge].minterParams.timestamp = block.timestamp;
    }

    /**
     * @notice Updates the limit of any bridge
     * @dev Can only be called by the owner
     * @param bridge The address of the bridge we are setting the limit too
     * @param limit The updated limit we are setting to the bridge
     */
    function _changeBurnerLimit(address bridge, uint256 limit) internal {
        uint256 oldLimit = bridges[bridge].burnerParams.maxLimit;
        uint256 currentLimit = burningCurrentLimitOf(bridge);
        bridges[bridge].burnerParams.maxLimit = limit;

        bridges[bridge].burnerParams.currentLimit = _calculateNewCurrentLimit(limit, oldLimit, currentLimit);

        bridges[bridge].burnerParams.ratePerSecond = limit / _DURATION;
        bridges[bridge].burnerParams.timestamp = block.timestamp;
    }

    /**
     * @notice Updates the current limit
     *
     * @param limit The new limit
     * @param oldLimit The old limit
     * @param currentLimit The current limit
     * @return _newCurrentLimit The new current limit
     */
    function _calculateNewCurrentLimit(uint256 limit, uint256 oldLimit, uint256 currentLimit)
        internal
        pure
        returns (uint256 _newCurrentLimit)
    {
        uint256 _difference;

        if (oldLimit > limit) {
            _difference = oldLimit - limit;
            _newCurrentLimit = currentLimit > _difference ? currentLimit - _difference : 0;
        } else {
            _difference = limit - oldLimit;
            _newCurrentLimit = currentLimit + _difference;
        }
    }

    /**
     * @notice Gets the current limit
     *
     * @param currentLimit The current limit
     * @param maxLimit The max limit
     * @param timestamp The timestamp of the last update
     * @param ratePerSecond The rate per second
     * @return limit The current limit
     */
    function _getCurrentLimit(uint256 currentLimit, uint256 maxLimit, uint256 timestamp, uint256 ratePerSecond)
        internal
        view
        returns (uint256 limit)
    {
        limit = currentLimit;
        if (limit == maxLimit) {
            return limit;
        } else if (timestamp + _DURATION <= block.timestamp) {
            limit = maxLimit;
        } else if (timestamp + _DURATION > block.timestamp) {
            uint256 _timePassed = block.timestamp - timestamp;
            uint256 _calculatedLimit = limit + (_timePassed * ratePerSecond);
            limit = _calculatedLimit > maxLimit ? maxLimit : _calculatedLimit;
        }
    }

    /**
     * @notice Internal function for burning tokens
     *
     * @param caller The caller address
     * @param user The user address
     * @param amount The amount to burn
     */
    function _burnWithCaller(address caller, address user, uint256 amount) internal {
        if (caller != lockbox) {
            uint256 currentLimit = burningCurrentLimitOf(caller);
            if (currentLimit < amount) revert IXERC20_NotHighEnoughLimits();
            _useBurnerLimits(caller, amount);
        }
        _burn(user, amount);
    }

    /**
     * @notice Internal function for minting tokens
     *
     * @param caller The caller address
     * @param user The user address
     * @param amount The amount to mint
     */
    function _mintWithCaller(address caller, address user, uint256 amount) internal {
        if (caller != lockbox) {
            uint256 currentLimit = mintingCurrentLimitOf(caller);
            if (currentLimit < amount) revert IXERC20_NotHighEnoughLimits();
            _useMinterLimits(caller, amount);
        }
        _mint(user, amount);
    }

    /**
     * @dev Authorizes an upgrade to a new implementation
     * Restricted access
     * @param newImplementation The address of the new implementation
     */
    // slither-disable-next-line dead-code
    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }
}

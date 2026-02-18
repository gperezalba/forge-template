// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

//solhint-disable func-name-mixedcase
//solhint-disable no-empty-blocks

/// @title UUPSOwnable2Step
/// @author gperezalba
/// @notice Implementation of UUPS proxy pattern with two-step ownership transfer
/// @dev Combines UUPSUpgradeable with Ownable2StepUpgradeable for secure upgradeable contracts
/// @custom:security-contact security@yourproject.com
contract UUPSOwnable2Step is UUPSUpgradeable, Ownable2StepUpgradeable {
    /// @notice Initializes the contract
    /// @dev Empty initialization as core initialization is handled by parent contracts
    /// @custom:oz-upgrades-unsafe-allow constructor
    function __UUPSOwnable2Step_init() internal onlyInitializing {
        __UUPSOwnable2Step_init_unchained();
    }

    /// @notice Additional initialization logic (if needed in the future)
    /// @dev Empty initialization, maintained for potential future use
    function __UUPSOwnable2Step_init_unchained() internal onlyInitializing {}

    /// @notice Authorizes an upgrade to a new implementation
    /// @dev Can only be called by the owner
    /// @param newImplementation Address of the new implementation contract
    function _authorizeUpgrade(address newImplementation) internal view virtual override onlyOwner {}

    /// @notice Gets the address of the current implementation
    /// @dev Uses ERC1967Utils to retrieve the implementation address
    /// @return The address of the current implementation contract
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }
}

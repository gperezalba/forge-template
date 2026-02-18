// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {UUPSOwnable2Step} from "src/utils/proxy/UUPSOwnable2Step.sol";
import {ICounter} from "src/interfaces/ICounter.sol";

/// @title Counter
/// @author gperezalba
/// @notice Upgradeable counter contract with owner-restricted set and public increment
contract Counter is UUPSOwnable2Step, ICounter {
    /// @notice The current stored number
    uint256 public number;

    /// @notice Initializes the contract setting the owner and upgradeability
    /// @param owner_ Address of the contract owner
    function initialize(address owner_) public initializer {
        if (owner_ == address(0)) revert Counter_ZeroAddress();

        __Ownable_init(owner_);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
        __UUPSOwnable2Step_init();
    }

    /// @notice Sets the stored number to a new value
    /// @param newNumber The new value to store
    function setNumber(uint256 newNumber) public onlyOwner {
        number = newNumber;
    }

    /// @notice Increments the stored number by one
    function increment() public {
        number++;
    }
}

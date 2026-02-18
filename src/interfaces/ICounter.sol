// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

/// @title ICounter
/// @author gperezalba
/// @notice Interface for the Counter contract
interface ICounter {
    /// @notice Thrown when the provided address is the zero address
    error Counter_ZeroAddress();

    /// @notice Initializes the contract with the given owner
    /// @param owner_ Address of the contract owner
    function initialize(address owner_) external;

    /// @notice Sets the stored number to a new value
    /// @param newNumber The new value to store
    function setNumber(uint256 newNumber) external;

    /// @notice Increments the stored number by one
    function increment() external;
}

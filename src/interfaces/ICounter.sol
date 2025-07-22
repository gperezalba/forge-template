// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface ICounter {
    error Counter_ZeroAddress();

    function initialize(address owner_) external;

    function setNumber(uint256 newNumber) external;

    function increment() external;
}

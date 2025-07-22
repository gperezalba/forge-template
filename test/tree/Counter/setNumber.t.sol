// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

import {Fixture} from "test/shared/Fixture.sol";
import {Counter} from "src/Counter.sol";

contract CounterSetNumberTest is Test, Fixture {
    Counter internal testCounter;

    function setUp() public {
        testCounter = counter;
    }

    modifier givenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_WhenNewNumberIsZeroAsOwner() external givenTheCallerIsTheOwner {
        uint256 newNumber = 0;

        // Call setNumber
        testCounter.setNumber(newNumber);

        // it should set number to zero
        assertEq(testCounter.number(), newNumber);

        // it should update the storage correctly
        assertEq(testCounter.number(), 0);
    }

    function test_WhenNewNumberIsAPositiveValueAsOwner() external givenTheCallerIsTheOwner {
        uint256 newNumber = 42;

        // Call setNumber
        testCounter.setNumber(newNumber);

        // it should set number to newNumber
        assertEq(testCounter.number(), newNumber);

        // it should update the storage correctly
        assertEq(testCounter.number(), 42);
    }

    function test_WhenNewNumberIsALargeValueAsOwner() external givenTheCallerIsTheOwner {
        uint256 newNumber = 1e18; // Large value

        // Call setNumber
        testCounter.setNumber(newNumber);

        // it should set number to the large value
        assertEq(testCounter.number(), newNumber);

        // it should update the storage correctly
        assertEq(testCounter.number(), 1e18);
    }

    function test_WhenNewNumberIsTheMaximumUint256ValueAsOwner() external givenTheCallerIsTheOwner {
        uint256 newNumber = type(uint256).max;

        // Call setNumber
        testCounter.setNumber(newNumber);

        // it should set number to max uint256
        assertEq(testCounter.number(), newNumber);

        // it should update the storage correctly
        assertEq(testCounter.number(), type(uint256).max);
    }

    modifier givenTheCallerIsNotTheOwner() {
        vm.startPrank(nonOwner);
        _;
        vm.stopPrank();
    }

    function test_WhenNewNumberIsZeroAsNon_owner() external givenTheCallerIsNotTheOwner {
        uint256 newNumber = 0;

        // it should revert with OwnableUnauthorizedAccount
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        testCounter.setNumber(newNumber);
    }

    function test_WhenNewNumberIsAPositiveValueAsNon_owner() external givenTheCallerIsNotTheOwner {
        uint256 newNumber = 42;

        // it should revert with OwnableUnauthorizedAccount
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        testCounter.setNumber(newNumber);
    }

    function test_WhenNewNumberIsALargeValueAsNon_owner() external givenTheCallerIsNotTheOwner {
        uint256 newNumber = 1e18;

        // it should revert with OwnableUnauthorizedAccount
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        testCounter.setNumber(newNumber);
    }

    function test_WhenNewNumberIsTheMaximumUint256ValueAsNon_owner() external givenTheCallerIsNotTheOwner {
        uint256 newNumber = type(uint256).max;

        // it should revert with OwnableUnauthorizedAccount
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        testCounter.setNumber(newNumber);
    }

    // Additional test to verify state doesn't change on failed calls
    function test_StateUnchangedAfterFailedSetNumber() external {
        uint256 initialNumber = testCounter.number();

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        testCounter.setNumber(123);

        // State should remain unchanged
        assertEq(testCounter.number(), initialNumber);
    }
}

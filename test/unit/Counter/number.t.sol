// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {CounterBase} from "test/CounterBase.t.sol";
import {Counter} from "src/Counter.sol";

contract CounterNumberTest is Test, CounterBase {
    Counter internal testCounter;

    function setUp() public override {
        super.setUp();
        testCounter = counter;
    }

    function test_GivenTheNumberIsZero() external {
        // Set number to zero
        vm.prank(owner);
        testCounter.setNumber(0);

        // it should return zero
        assertEq(testCounter.number(), 0);

        // it should not revert
        // No revert expected for view function
        uint256 result = testCounter.number();
        assertEq(result, 0);
    }

    function test_GivenTheNumberIsOne() external {
        // Set number to one
        vm.prank(owner);
        testCounter.setNumber(1);

        // it should return one
        assertEq(testCounter.number(), 1);

        // it should not revert
        uint256 result = testCounter.number();
        assertEq(result, 1);
    }

    function test_GivenTheNumberIsASmallPositiveValue() external {
        uint256 smallValue = 42;

        // Set number to small positive value
        vm.prank(owner);
        testCounter.setNumber(smallValue);

        // it should return the exact stored value
        assertEq(testCounter.number(), smallValue);

        // it should not revert
        uint256 result = testCounter.number();
        assertEq(result, 42);
    }

    function test_GivenTheNumberIsALargePositiveValue() external {
        uint256 largeValue = 1e18; // 1 * 10^18

        // Set number to large positive value
        vm.prank(owner);
        testCounter.setNumber(largeValue);

        // it should return the exact stored value
        assertEq(testCounter.number(), largeValue);

        // it should not revert
        uint256 result = testCounter.number();
        assertEq(result, 1e18);
    }

    function test_GivenTheNumberIsTheMaximumUint256Value() external {
        uint256 maxValue = type(uint256).max;

        // Set number to maximum uint256 value
        vm.prank(owner);
        testCounter.setNumber(maxValue);

        // it should return the maximum uint256 value
        assertEq(testCounter.number(), maxValue);

        // it should not revert
        uint256 result = testCounter.number();
        assertEq(result, type(uint256).max);
    }

    // Additional comprehensive tests
    function test_NumberGetterMultipleCalls() external {
        uint256 testValue = 12345;

        vm.prank(owner);
        testCounter.setNumber(testValue);

        // Multiple calls should return the same value
        assertEq(testCounter.number(), testValue);
        assertEq(testCounter.number(), testValue);
        assertEq(testCounter.number(), testValue);

        // Value should be consistent
        uint256 first = testCounter.number();
        uint256 second = testCounter.number();
        assertEq(first, second);
    }

    function test_NumberGetterAfterIncrement() external {
        uint256 initialValue = 100;

        vm.prank(owner);
        testCounter.setNumber(initialValue);

        // Check initial value
        assertEq(testCounter.number(), initialValue);

        // Increment and check new value
        testCounter.increment();
        assertEq(testCounter.number(), initialValue + 1);

        // Increment again
        testCounter.increment();
        assertEq(testCounter.number(), initialValue + 2);
    }

    function test_NumberGetterFromDifferentCallers() external {
        uint256 testValue = 777;

        vm.prank(owner);
        testCounter.setNumber(testValue);

        // Owner can read
        vm.prank(owner);
        assertEq(testCounter.number(), testValue);

        // Non-owner can read
        vm.prank(nonOwner);
        assertEq(testCounter.number(), testValue);

        // Random address can read
        address randomUser = makeAddr("randomUser");
        vm.prank(randomUser);
        assertEq(testCounter.number(), testValue);
    }

    function test_NumberGetterIsView() external {
        uint256 testValue = 555;

        vm.prank(owner);
        testCounter.setNumber(testValue);

        // Store gas before call
        uint256 gasBefore = gasleft();
        uint256 result = testCounter.number();
        uint256 gasAfter = gasleft();

        // View function should not change state
        assertEq(result, testValue);

        // Call again to ensure state didn't change
        assertEq(testCounter.number(), testValue);

        // Note: In tests, view functions may still consume gas,
        // but they don't modify state
    }

    function test_NumberGetterWithEdgeValues() external {
        uint256[] memory edgeValues = new uint256[](5);
        edgeValues[0] = 0;
        edgeValues[1] = 1;
        edgeValues[2] = type(uint256).max / 2;
        edgeValues[3] = type(uint256).max - 1;
        edgeValues[4] = type(uint256).max;

        for (uint256 i = 0; i < edgeValues.length; i++) {
            vm.prank(owner);
            testCounter.setNumber(edgeValues[i]);

            assertEq(testCounter.number(), edgeValues[i]);
        }
    }
}

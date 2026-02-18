// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Test} from "forge-std/Test.sol";

import {CounterBase} from "test/CounterBase.t.sol";
import {Counter} from "src/Counter.sol";

contract CounterIncrementTest is Test, CounterBase {
    Counter internal testCounter;

    function setUp() public override {
        super.setUp();
        testCounter = counter;
    }

    function test_GivenTheCurrentNumberIsZero() external {
        // Set initial state: number = 0
        vm.prank(owner);
        testCounter.setNumber(0);

        // Call increment
        testCounter.increment();

        // it should increment number to one
        assertEq(testCounter.number(), 1);

        // it should update the storage correctly
        assertEq(testCounter.number(), 1);
    }

    function test_GivenTheCurrentNumberIsOne() external {
        // Set initial state: number = 1
        vm.prank(owner);
        testCounter.setNumber(1);

        // Call increment
        testCounter.increment();

        // it should increment number to two
        assertEq(testCounter.number(), 2);

        // it should update the storage correctly
        assertEq(testCounter.number(), 2);
    }

    function test_GivenTheCurrentNumberIsAPositiveValueLessThanMaxUint256() external {
        uint256 initialValue = 999;

        // Set initial state: number = 999
        vm.prank(owner);
        testCounter.setNumber(initialValue);

        // Call increment
        testCounter.increment();

        // it should increment number by one
        assertEq(testCounter.number(), initialValue + 1);

        // it should update the storage correctly
        assertEq(testCounter.number(), 1000);
    }

    function test_GivenTheCurrentNumberIsCloseToMaximumUint256Value() external {
        uint256 closeToMax = type(uint256).max - 10; // Very close to max

        // Set initial state: number = max - 10
        vm.prank(owner);
        testCounter.setNumber(closeToMax);

        // Call increment
        testCounter.increment();

        // it should increment number by one
        assertEq(testCounter.number(), closeToMax + 1);

        // it should update the storage correctly
        assertEq(testCounter.number(), type(uint256).max - 9);
    }

    function test_GivenTheCurrentNumberIsTheMaximumUint256Value() external {
        // Set initial state: number = max uint256
        vm.prank(owner);
        testCounter.setNumber(type(uint256).max);

        // it should revert with arithmetic overflow error
        vm.expectRevert(); // Arithmetic overflow in Solidity 0.8+
        testCounter.increment();
    }

    // Additional edge case tests
    function test_MultipleIncrements() external {
        // Set initial state: number = 5
        vm.prank(owner);
        testCounter.setNumber(5);

        // Multiple increments
        testCounter.increment(); // 5 -> 6
        assertEq(testCounter.number(), 6);

        testCounter.increment(); // 6 -> 7
        assertEq(testCounter.number(), 7);

        testCounter.increment(); // 7 -> 8
        assertEq(testCounter.number(), 8);
    }

    function test_IncrementFromMaxMinusOne() external {
        uint256 maxMinusOne = type(uint256).max - 1;

        // Set initial state: number = max - 1
        vm.prank(owner);
        testCounter.setNumber(maxMinusOne);

        // This should work (max - 1 + 1 = max)
        testCounter.increment();
        assertEq(testCounter.number(), type(uint256).max);

        // But the next one should revert
        vm.expectRevert(); // Arithmetic overflow
        testCounter.increment();
    }

    // Test increment with different callers (anyone can call increment)
    function test_IncrementCalledByNonOwner() external {
        vm.prank(owner);
        testCounter.setNumber(10);

        // Non-owner should be able to call increment
        vm.prank(nonOwner);
        testCounter.increment();

        assertEq(testCounter.number(), 11);
    }

    function test_IncrementCalledByRandomAddress() external {
        address randomUser = makeAddr("randomUser");

        vm.prank(owner);
        testCounter.setNumber(50);

        // Random address should be able to call increment
        vm.prank(randomUser);
        testCounter.increment();

        assertEq(testCounter.number(), 51);
    }
}

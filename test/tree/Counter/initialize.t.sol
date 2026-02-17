// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {CounterBase} from "test/CounterBase.t.sol";
import {Counter} from "src/Counter.sol";
import {ICounter} from "src/interfaces/ICounter.sol";

contract CounterInitializeTest is Test, CounterBase {
    // Events from OpenZeppelin
    event Initialized(uint64 version);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    Counter internal counterImplementation;
    Counter internal testCounter;

    function setUp() public override {
        super.setUp();
        // Deploy fresh implementation for testing
        counterImplementation = new Counter();
    }

    modifier givenTheContractIsNotInitialized() {
        // Deploy a fresh proxy without initialization
        testCounter = Counter(address(new ERC1967Proxy(address(counterImplementation), "")));
        _;
    }

    function test_WhenOwner_IsTheZeroAddressForFirstInitialization() external givenTheContractIsNotInitialized {
        // it should revert with Counter_ZeroAddress
        vm.expectRevert(abi.encodeWithSelector(ICounter.Counter_ZeroAddress.selector));
        testCounter.initialize(address(0));
    }

    function test_WhenOwner_IsNotTheZeroAddressForFirstInitialization() external givenTheContractIsNotInitialized {
        address newOwner = makeAddr("newOwner");

        // Expect OwnershipTransferred event first (this is emitted first)
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(0), newOwner);

        // Expect Initialized event second
        vm.expectEmit(true, false, false, true);
        emit Initialized(1);

        // Initialize the contract
        testCounter.initialize(newOwner);

        // it should set the owner correctly
        assertEq(testCounter.owner(), newOwner);

        // it should set the pending owner to zero address
        assertEq(testCounter.pendingOwner(), address(0));

        // it should initialize UUPS functionality
        // Verify UUPS is initialized by checking implementation
        assertEq(testCounter.implementation(), address(counterImplementation));

        // it should initialize Ownable2Step functionality
        // Verify can transfer ownership (2-step process)
        vm.prank(newOwner);
        testCounter.transferOwnership(owner);
        assertEq(testCounter.pendingOwner(), owner);

        // it should complete initialization successfully
        // Verify contract is marked as initialized
        vm.expectRevert(); // Should revert if trying to initialize again
        testCounter.initialize(newOwner);
    }

    modifier givenTheContractIsAlreadyInitialized() {
        // Use the already initialized counter from Fixture
        testCounter = counter;
        _;
    }

    function test_WhenOwner_IsTheZeroAddressForRe_initializationAttempt()
        external
        givenTheContractIsAlreadyInitialized
    {
        // it should revert with InvalidInitialization
        vm.expectRevert(); // InvalidInitialization from Initializable
        testCounter.initialize(address(0));
    }

    function test_WhenOwner_IsNotTheZeroAddressForRe_initializationAttempt()
        external
        givenTheContractIsAlreadyInitialized
    {
        address newOwner = makeAddr("anotherOwner");

        // it should revert with InvalidInitialization
        vm.expectRevert(); // InvalidInitialization from Initializable
        testCounter.initialize(newOwner);
    }
}

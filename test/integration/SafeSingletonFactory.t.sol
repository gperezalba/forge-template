// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Test} from "forge-std/Test.sol";

import {Create2Utils} from "script/utils/Create2Utils.sol";

/// @dev Integration tests that run against a forked network.
/// All function names must contain "testFork" so they are picked up
/// by `npm run test:fork` (--match-test testFork) and excluded from
/// `npm run test:local` (--no-match-test testFork).
contract SafeSingletonFactoryForkTest is Test {
    function testFork_SafeSingletonFactoryIsDeployed() external {
        uint256 codeSize = Create2Utils.SAFE_SINGLETON_FACTORY.code.length;
        assertGt(codeSize, 0, "SafeSingletonFactory should be deployed on the forked network");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Base} from "./Base.t.sol";

import {Counter} from "src/Counter.sol";

contract CounterBase is Base {
    // Contract instance for easy access
    Counter public counter;

    function setUp() public virtual override {
        super.setUp();
        counter = Counter(deployReport.proxies.counter);
        vm.label(address(counter), "counterProxy");
    }
}

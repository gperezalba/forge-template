// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {Utils} from "./Utils.s.sol";
import {Counter} from "src/Counter.sol";
import {Deployer} from "src/utils/Deployer.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function mint(address, uint256) external;
    function approve(address, uint256) external;
}

// solhint-disable immutable-vars-naming
contract Ecosystem is Script, Test, Utils {
    using stdJson for string;

    Deployer public immutable deployer;
    Counter public immutable counter;

    constructor() {
        deployer = Deployer(getAddressFromReport(".deployer"));
        counter = Counter(getAddressFromReport(".proxies.counter"));
    }
}

contract CounterSetNumber is Ecosystem {
    function run() external {
        vm.startBroadcast();
        counter.setNumber(100);
        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Counter} from "src/Counter.sol";
import {Deployer} from "src/utils/Deployer.sol";

// solhint-disable immutable-vars-naming
contract Ecosystem is Script {
    using stdJson for string;

    Deployer public immutable deployer;
    Counter public immutable counter;

    constructor() {
        deployer = Deployer(_getAddressFromReport(".deployer"));
        counter = Counter(_getAddressFromReport(".proxies.counter"));
    }

    function _getAddressFromReport(string memory key) internal view returns (address) {
        string memory env = vm.envString("ENV");
        string memory path =
            string.concat("./reports/", vm.toString(block.chainid), "/", env, "/latest-deployment.json");
        string memory json = vm.readFile(path);
        bytes memory data = json.parseRaw(key);
        return abi.decode(data, (address));
    }
}

contract CounterSetNumber is Ecosystem {
    function run() external {
        vm.startBroadcast();
        counter.setNumber(100);
        vm.stopBroadcast();
    }
}

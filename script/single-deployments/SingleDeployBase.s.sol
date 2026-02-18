// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Create2Utils} from "script/utils/Create2Utils.sol";

abstract contract SingleDeployBase is Script {
    using stdJson for string;

    function _getVersion() internal view returns (string memory) {
        return abi.decode(vm.parseJson(vm.readFile("package.json"), ".version"), (string));
    }

    function _getEnv() internal view returns (string memory) {
        return vm.envString("ENV");
    }

    function _getReportPath(string memory env) internal view returns (string memory) {
        return string.concat("./reports/", vm.toString(block.chainid), "/", env, "/latest-deployment.json");
    }

    function _readAddressFromReport(string memory reportPath, string memory key) internal view returns (address) {
        string memory json = vm.readFile(reportPath);
        return abi.decode(json.parseRaw(key), (address));
    }

    function _writeAddressToReport(string memory reportPath, string memory key, address addr) internal {
        vm.writeJson(string.concat('"', vm.toString(addr), '"'), reportPath, key);
    }

}

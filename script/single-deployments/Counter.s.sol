// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Counter} from "src/Counter.sol";
import {ICounter} from "src/interfaces/ICounter.sol";
import {Create2Utils} from "script/utils/Create2Utils.sol";
import {SingleDeployBase} from "./SingleDeployBase.s.sol";

/// @notice Deploys a new Counter implementation via CREATE2 and updates the report
contract DeployCounterImplementation is SingleDeployBase {
    function run() external {
        string memory version = _getVersion();
        string memory env = _getEnv();
        string memory reportPath = _getReportPath(env);

        console.log("Deploying Counter implementation");
        console.log("Version:", version);
        console.log("Environment:", env);

        vm.startBroadcast();
        Create2Utils.loadCreate2Factory();
        bytes32 salt = Create2Utils.computeSalt("Counter", version);
        address implementation = Create2Utils.create2Deploy(salt, type(Counter).creationCode);
        vm.stopBroadcast();

        console.log("Counter implementation:", implementation);

        _writeAddressToReport(reportPath, ".implementations.counter", implementation);

        console.log("DONE");
    }
}

/// @notice Deploys a new Counter implementation and an ERC1967 proxy pointing to it, then updates the report
contract DeployCounterProxy is SingleDeployBase {
    function run() external {
        string memory version = _getVersion();
        string memory env = _getEnv();
        string memory reportPath = _getReportPath(env);
        address owner = _readAddressFromReport(reportPath, ".owner");

        console.log("Deploying Counter implementation + proxy");
        console.log("Version:", version);
        console.log("Environment:", env);
        console.log("Owner:", owner);

        vm.startBroadcast();
        Create2Utils.loadCreate2Factory();
        bytes32 salt = Create2Utils.computeSalt("Counter", version);
        address implementation = Create2Utils.create2Deploy(salt, type(Counter).creationCode);

        bytes memory initializeCalldata = abi.encodeWithSelector(ICounter.initialize.selector, owner);
        address proxy = address(new ERC1967Proxy(implementation, initializeCalldata));
        vm.stopBroadcast();

        console.log("Counter implementation:", implementation);
        console.log("Counter proxy:", proxy);

        _writeAddressToReport(reportPath, ".implementations.counter", implementation);
        _writeAddressToReport(reportPath, ".proxies.counter", proxy);

        console.log("DONE");
    }
}

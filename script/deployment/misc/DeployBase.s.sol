// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

// solhint-disable no-console
// solhint-disable custom-errors

import {Script, console} from "forge-std/Script.sol";
import {ConfigAbstract} from "../config/ConfigAbstract.sol";
import {DeployContracts} from "./DeployContracts.sol";
import {DeployReport} from "./DeployReport.s.sol";

abstract contract DeployBase is ConfigAbstract, Script, DeployReport, DeployContracts {
    function run() external {
        console.log("PROJECT deployment");
        console.log("sender", msg.sender);
        ConfigAbstract.Config memory config = _getInitialConfig();
        _checkInitialConfig(config);
        vm.startBroadcast();
        DeployContracts.Report memory deployReport = _deployContracts(config.deployerConfig);
        vm.stopBroadcast();
        ConfigAbstract.EnvConfig memory envConfig = _getEnvConfig();
        console.log("Generate report");
        _writeJsonDeployReport(deployReport, config.env, envConfig);
        console.log("DONE");
    }

    function _checkInitialConfig(ConfigAbstract.Config memory config) internal pure {
        require(config.deployerConfig.owner != address(0), "config.owner is zero address");
    }
}

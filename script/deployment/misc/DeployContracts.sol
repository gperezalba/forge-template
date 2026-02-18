// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import {Counter} from "src/Counter.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {Create2Utils} from "script/utils/Create2Utils.sol";

contract DeployContracts {
    struct Report {
        Deployer.Config deployerConfig;
        Deployer.Addresses implementations;
        Deployer.Addresses proxies;
        address deployer;
    }

    function _deployContracts(Deployer.Config memory deployerConfig, string memory envLabel, string memory version)
        internal
        returns (Report memory deployReport)
    {
        Create2Utils.loadCreate2Factory();
        Deployer.Addresses memory implementations = _deployImplementations(version);
        (Deployer.Addresses memory proxies, Deployer deployer) =
            _deployDeployer(implementations, deployerConfig, envLabel, version);
        deployReport.deployerConfig = deployerConfig;
        deployReport.implementations = implementations;
        deployReport.proxies = proxies;
        deployReport.deployer = address(deployer);
        return deployReport;
    }

    function _deployImplementations(string memory version) internal returns (Deployer.Addresses memory implementations) {
        bytes32 salt = Create2Utils.computeSalt("Counter", version);
        implementations.counter = Create2Utils.create2Deploy(salt, type(Counter).creationCode);
        return implementations;
    }

    function _deployDeployer(
        Deployer.Addresses memory implementations,
        Deployer.Config memory deployerConfig,
        string memory envLabel,
        string memory version
    ) internal returns (Deployer.Addresses memory proxies, Deployer deployer) {
        bytes32 salt = Create2Utils.computeSalt("Deployer", envLabel, version);
        deployer = Deployer(Create2Utils.create2Deploy(salt, type(Deployer).creationCode));
        if (deployer.counter() == address(0)) {
            deployer.deploy(implementations, deployerConfig);
        }
        proxies.counter = deployer.counter();
    }
}

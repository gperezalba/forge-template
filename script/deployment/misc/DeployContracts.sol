// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import {Counter} from "src/Counter.sol";
import {Deployer} from "src/utils/Deployer.sol";

contract DeployContracts {
    struct Report {
        Deployer.Config deployerConfig;
        Deployer.Addresses implementations;
        Deployer.Addresses proxies;
        address deployer;
    }

    function _deployContracts(Deployer.Config memory deployerConfig) internal returns (Report memory deployReport) {
        Deployer.Addresses memory implementations = _deployImplementations();
        (Deployer.Addresses memory proxies, Deployer deployer) = _deployDeployer(implementations, deployerConfig);
        deployReport.deployerConfig = deployerConfig;
        deployReport.implementations = implementations;
        deployReport.proxies = proxies;
        deployReport.deployer = address(deployer);
        return deployReport;
    }

    function _deployImplementations() internal returns (Deployer.Addresses memory implementations) {
        implementations.counter = address(new Counter());
        return implementations;
    }

    function _deployDeployer(Deployer.Addresses memory implementations, Deployer.Config memory deployerConfig)
        internal
        returns (Deployer.Addresses memory proxies, Deployer deployer)
    {
        deployer = new Deployer(implementations, deployerConfig);
        proxies.counter = deployer.COUNTER();
    }
}

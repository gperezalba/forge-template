// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {DeployContracts} from "script/deployment/misc/DeployContracts.sol";
import {ConfigAbstract, Deployer} from "script/deployment/config/ConfigAbstract.sol";

import {ERC20Mock} from "./mocks/ERC20Mock.sol";

import {Counter} from "src/Counter.sol";

// solhint-disable no-console
// solhint-disable immutable-vars-naming

contract Fixture is Test, DeployContracts, ConfigAbstract {
    // Test accounts
    address public immutable owner;
    address public immutable nonOwner;

    // Deployed system
    DeployContracts.Report public deployReport;

    // Mock USDT for testing
    ERC20Mock public immutable mockUSDT;

    // Contract instances for easy access
    Counter public counter;

    constructor() {
        owner = makeAddr("test_owner");
        nonOwner = makeAddr("test_non_owner");
        mockUSDT = new ERC20Mock("Test USDT", "TUSDT", 6);

        // Deploy contracts
        _deployProjectContracts();

        // Initialize counter reference
        counter = Counter(deployReport.proxies.counter);
    }

    function _deployProjectContracts() internal {
        Config memory config = _getInitialConfig();
        deployReport = _deployContracts(config.deployerConfig);
    }

    function _getInitialConfig() internal view override returns (Config memory config) {
        config.env = Environment.DEV;
        config.deployerConfig = Deployer.Config({owner: owner});
        return config;
    }

    function _getEnvConfig() internal view override returns (EnvConfig memory envConfig) {
        envConfig = EnvConfig({usdt: address(mockUSDT)});
        return envConfig;
    }
}

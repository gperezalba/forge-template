// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {DeployContracts} from "script/deployment/misc/DeployContracts.sol";
import {ConfigAbstract, Deployer} from "script/deployment/config/ConfigAbstract.sol";

import {ERC20Mock} from "./mocks/ERC20Mock.sol";

// solhint-disable no-console
// solhint-disable immutable-vars-naming

contract Base is Test, DeployContracts, ConfigAbstract {
    // Test accounts
    address public owner = makeAddr("owner");
    address public nonOwner = makeAddr("nonOwner");

    // Deployed system
    DeployContracts.Report public deployReport;

    // Mock USDT for testing
    ERC20Mock public mockUSDT = new ERC20Mock("Test USDT", "TUSDT", 6);

    function setUp() public virtual {
        vm.label(address(mockUSDT), "mockUSDT");

        // Deploy contracts
        _deployProjectContracts();

        vm.label(deployReport.deployer, "deployer");
        vm.label(deployReport.implementations.counter, "counterImpl");
    }

    function _deployProjectContracts() internal {
        Config memory config = _getInitialConfig();
        string memory version = abi.decode(vm.parseJson(vm.readFile("package.json"), ".version"), (string));
        deployReport = _deployContracts(config.deployerConfig, "DEV", version);
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

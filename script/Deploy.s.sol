// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {Utils} from "./Utils.s.sol";
import {Deployer} from "../src/Deployer.sol";

contract DeployScript is Script, Test, Utils {
    address public ms;

    function setUp() public {
        ms = getAddressFromConfigJson(".MS");
    }

    function run() external {
        vm.startBroadcast();

        Deployer deployer = deployDeployer();
        string memory configPath = getJsonConfigPath();
        vm.writeJson(vm.toString(address(deployer)), configPath, ".DEPLOYER");

        vm.stopBroadcast();
    }

    function deployDeployer() public returns (Deployer deployer) {
        deployer = new Deployer();
    }
}

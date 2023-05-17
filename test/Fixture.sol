// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {Utils} from "../script/Utils.s.sol";
import {DeployScript} from "../script/Deploy.s.sol";
import {Deployer} from "../src/Deployer.sol";

contract Fixture is Test, Utils {
    DeployScript public deployScript;

    Deployer public deployer;
    address public ms = getAddressFromConfigJson(".MS");

    constructor() {
        deployScript = new DeployScript();
        deployer = deployScript.deployDeployer();
    }
}

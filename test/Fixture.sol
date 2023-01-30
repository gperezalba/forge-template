// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {Utils} from "../script/Utils.s.sol";
import {DeployScript} from "../script/Deploy.s.sol";
import {Deployer} from "../src/Deployer.sol";

string constant ROOT_PATH = "./addresses/";

contract Fixture is Test, Utils {
    DeployScript public deployScript;

    Deployer public deployer;
    address public ms = readAddressFromFile(ROOT_PATH, _getChainID(), "MS.txt");

    constructor() {
        deployScript = new DeployScript();
        deployer = deployScript.deployDeployer();
    }

    function _getChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}

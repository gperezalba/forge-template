// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {Utils} from "./Utils.s.sol";
import {Deployer} from "../src/Deployer.sol";

string constant ROOT_PATH = "./addresses/";

contract DeployScript is Script, Test, Utils {
    uint256 public chainId;
    address public ms;

    function setUp() public {
        chainId = _getChainID();
        _customSetUp();
    }

    function run() external {
        vm.startBroadcast();

        Deployer deployer = deployDeployer();
        writeAddress2File(ROOT_PATH, chainId, "Deployer.txt", address(deployer));

        vm.stopBroadcast();
    }

    function deployDeployer() public returns (Deployer deployer) {
        deployer = new Deployer();
    }

    function _customSetUp() internal {
        ms = readAddressFromFile(ROOT_PATH, chainId, "MS.txt");
    }

    function _getChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}

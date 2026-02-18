// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Script} from "forge-std/Script.sol";
import {DeployContracts} from "./DeployContracts.sol";
import {ConfigAbstract} from "../config/ConfigAbstract.sol";

contract DeployReport is Script {
    function _writeJsonDeployReport(
        DeployContracts.Report memory report,
        ConfigAbstract.Environment env,
        ConfigAbstract.EnvConfig memory envConfig
    ) internal {
        (string memory factoryV3Commit, string memory factoryV3Branch) = getGitModuleVersion();
        string memory jsonReport = "project-report";

        string memory githubOutput;
        string memory proxiesOutput;
        string memory impOutput;
        string memory tokensOutput;

        {
            string memory jsonGithub = "github";
            vm.serializeString(jsonGithub, "repository-commit", factoryV3Commit);
            githubOutput = vm.serializeString(jsonGithub, "repository-branch", factoryV3Branch);
        }
        //proxies
        {
            string memory jsonProxies = "proxies";
            proxiesOutput = vm.serializeAddress(jsonProxies, "counter", report.proxies.counter);
        }
        //implementations
        {
            string memory jsonImplementations = "implementations";
            impOutput = vm.serializeAddress(jsonImplementations, "counter", report.implementations.counter);
        }
        //tokens
        {
            string memory jsonTokens = "tokens";
            tokensOutput = vm.serializeAddress(jsonTokens, "usdt", envConfig.usdt);
        }

        //general
        vm.serializeAddress(jsonReport, "owner", report.deployerConfig.owner);
        vm.serializeAddress(jsonReport, "deployer", report.deployer);
        vm.serializeString(jsonReport, "github", githubOutput);
        vm.serializeString(jsonReport, "proxies", proxiesOutput);
        vm.serializeString(jsonReport, "tokens", tokensOutput);
        string memory json = vm.serializeString(jsonReport, "implementations", impOutput);
        string memory environment = getEnvironmentFromEnum(env);
        vm.writeJson(
            json,
            string.concat(
                "./reports/", vm.toString(block.chainid), "/", environment, "/", getTimestamp(), "-deployment.json"
            )
        );
        vm.writeJson(
            json, string.concat("./reports/", vm.toString(block.chainid), "/", environment, "/latest-deployment.json")
        );
    }

    function getEnvironmentFromEnum(ConfigAbstract.Environment envEnum) public pure returns (string memory env) {
        if (envEnum == ConfigAbstract.Environment.DEV) return "DEV";
        if (envEnum == ConfigAbstract.Environment.INT) return "INT";
        if (envEnum == ConfigAbstract.Environment.STA) return "STA";
        if (envEnum == ConfigAbstract.Environment.PRO) return "PRO";
    }

    function getTimestamp() public returns (string memory result) {
        string[] memory command = new string[](3);

        command[0] = "bash";
        command[1] = "-c";
        command[2] = 'response="$(date +%s)"; cast abi-encode "response(string)" $response;';
        bytes memory timestamp = vm.ffi(command);
        (result) = abi.decode(timestamp, (string));

        return result;
    }

    function getGitModuleVersion() public returns (string memory commit, string memory branch) {
        string[] memory commitCommand = new string[](3);
        string[] memory branchCommand = new string[](3);

        commitCommand[0] = "bash";
        commitCommand[1] = "-c";
        commitCommand[2] = 'response="$(echo -n $(git rev-parse HEAD))"; cast abi-encode "response(string)" "$response"';

        bytes memory commitResponse = vm.ffi(commitCommand);

        (commit) = abi.decode(commitResponse, (string));

        branchCommand[0] = "bash";
        branchCommand[1] = "-c";
        branchCommand[2] =
            'response="$(echo -n $(git branch --show-current))"; cast abi-encode "response(string)" "$response"';

        bytes memory response = vm.ffi(branchCommand);

        (branch) = abi.decode(response, (string));

        return (commit, branch);
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import {ConfigAbstract, Deployer} from "./ConfigAbstract.sol";

contract ConfigSepoliaINT is ConfigAbstract {
    ConfigAbstract.Environment internal constant _ENV = ConfigAbstract.Environment.INT;
    address internal constant _OWNER = 0xCD7669AAFffB7F683995E6eD9b53d1E5FE72c142;
    address internal constant _USDT = 0x118f6C0090ffd227CbeFE1C6d8A803198c4422F0;

    function _getInitialConfig() internal pure override returns (Config memory config) {
        config.env = _ENV;
        config.deployerConfig = Deployer.Config({owner: _OWNER});
        return config;
    }

    function _getEnvConfig() internal pure override returns (EnvConfig memory envConfig) {
        envConfig = EnvConfig({usdt: _USDT});
        return envConfig;
    }
}

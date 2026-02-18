// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

// solhint-disable

import {ConfigAbstract, Deployer} from "./ConfigAbstract.sol";

contract ConfigPolygon is ConfigAbstract {
    ConfigAbstract.Environment internal constant _ENV = ConfigAbstract.Environment.PRO;
    address internal constant _OWNER = 0x94D300A6629BD1C51c632f070De929F5e96eE139;
    address internal constant _USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

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

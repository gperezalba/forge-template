// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Deployer} from "src/utils/Deployer.sol";

abstract contract ConfigAbstract {
    enum Environment {
        DEV,
        INT,
        STA,
        PRO
    }

    struct Config {
        Environment env;
        Deployer.Config deployerConfig;
    }

    struct EnvConfig {
        address usdt;
    }

    function _getInitialConfig() internal virtual returns (Config memory config);
    function _getEnvConfig() internal view virtual returns (EnvConfig memory envConfig);
}

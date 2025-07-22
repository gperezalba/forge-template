// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

// solhint-disable no-empty-blocks

import {DeployBase} from "./misc/DeployBase.s.sol";
import {ConfigSepoliaSTA} from "./config/ConfigSepoliaSTA.sol";

contract DeploySepoliaSTA is DeployBase, ConfigSepoliaSTA {}

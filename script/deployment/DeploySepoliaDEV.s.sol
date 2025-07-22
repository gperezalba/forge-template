// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

// solhint-disable no-empty-blocks

import {DeployBase} from "./misc/DeployBase.s.sol";
import {ConfigSepoliaDEV} from "./config/ConfigSepoliaDEV.sol";

contract DeploySepoliaDEV is DeployBase, ConfigSepoliaDEV {}

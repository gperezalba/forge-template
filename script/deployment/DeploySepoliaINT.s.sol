// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

// solhint-disable no-empty-blocks

import {DeployBase} from "./misc/DeployBase.s.sol";
import {ConfigSepoliaINT} from "./config/ConfigSepoliaINT.sol";

contract DeploySepoliaINT is DeployBase, ConfigSepoliaINT {}

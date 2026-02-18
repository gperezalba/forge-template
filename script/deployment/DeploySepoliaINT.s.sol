// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

// solhint-disable

import {DeployBase} from "./misc/DeployBase.s.sol";
import {ConfigSepoliaINT} from "./config/ConfigSepoliaINT.sol";

contract DeploySepoliaINT is DeployBase, ConfigSepoliaINT {}

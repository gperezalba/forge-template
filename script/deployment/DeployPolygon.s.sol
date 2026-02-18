// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

// solhint-disable

import {DeployBase} from "./misc/DeployBase.s.sol";
import {ConfigPolygon} from "./config/ConfigPolygon.sol";

contract DeployPolygon is DeployBase, ConfigPolygon {}

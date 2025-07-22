// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {UUPSOwnable2Step} from "src/utils/proxy/UUPSOwnable2Step.sol";
import {ICounter} from "src/interfaces/ICounter.sol";

contract Counter is UUPSOwnable2Step, ICounter {
    uint256 public number;

    function initialize(address owner_) public initializer {
        if (owner_ == address(0)) revert Counter_ZeroAddress();

        __Ownable_init(owner_);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
        __UUPSOwnable2Step_init();
    }

    function setNumber(uint256 newNumber) public onlyOwner {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}

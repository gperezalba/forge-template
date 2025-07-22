// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ICounter} from "src/interfaces/ICounter.sol";

contract Deployer {
    struct Addresses {
        address counter;
    }

    struct Config {
        address owner;
    }

    address public immutable COUNTER;

    event Deploy(address counter);

    constructor(Addresses memory implementations, Config memory config) {
        {
            bytes memory initializeCalldata = abi.encodeWithSelector(ICounter.initialize.selector, config.owner);
            COUNTER = _createProxy(implementations.counter, initializeCalldata);
        }

        emit Deploy(COUNTER);
    }

    function _createProxy(address proxyImplementation, bytes memory initializeCalldata)
        internal
        returns (address proxyAddress)
    {
        proxyAddress = address(new ERC1967Proxy(proxyImplementation, initializeCalldata));
    }
}

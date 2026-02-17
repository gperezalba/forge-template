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

    address public immutable AUTHORIZED;
    address public COUNTER;
    bool private _deployed;

    error Deployer_Unauthorized();
    error Deployer_AlreadyDeployed();

    event Deploy(address counter);

    constructor() {
        AUTHORIZED = tx.origin;
    }

    function deploy(Addresses memory implementations, Config memory config) external {
        if (tx.origin != AUTHORIZED) revert Deployer_Unauthorized();
        if (_deployed) revert Deployer_AlreadyDeployed();
        _deployed = true;

        bytes memory initializeCalldata = abi.encodeWithSelector(ICounter.initialize.selector, config.owner);
        COUNTER = _createProxy(implementations.counter, initializeCalldata);

        emit Deploy(COUNTER);
    }

    function _createProxy(address proxyImplementation, bytes memory initializeCalldata)
        internal
        returns (address proxyAddress)
    {
        proxyAddress = address(new ERC1967Proxy(proxyImplementation, initializeCalldata));
    }
}

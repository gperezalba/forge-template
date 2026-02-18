// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ICounter} from "src/interfaces/ICounter.sol";

/// @title Deployer
/// @author gperezalba
/// @notice Deploys and initializes project proxies in a single transaction
contract Deployer {
    /// @notice Addresses of the contract implementations or proxies
    struct Addresses {
        address counter;
    }

    /// @notice Configuration for the deployment
    struct Config {
        address owner;
    }

    /// @notice Address authorized to trigger the deployment
    address public immutable AUTHORIZED;

    /// @notice Address of the deployed Counter proxy
    address public counter;

    /// @dev Whether the deployment has already been executed
    bool private _deployed;

    /// @notice Thrown when the caller is not the authorized deployer
    error Deployer_Unauthorized();

    /// @notice Thrown when deploy is called more than once
    error Deployer_AlreadyDeployed();

    /// @notice Emitted when the deployment is executed
    /// @param counter Address of the deployed Counter proxy
    event Deploy(address indexed counter);

    /// @notice Sets the authorized deployer to the contract creator
    constructor() {
        AUTHORIZED = msg.sender;
    }

    /// @notice Deploys and initializes all project proxies
    /// @param implementations Addresses of the implementation contracts
    /// @param config Deployment configuration (owner, etc.)
    function deploy(Addresses memory implementations, Config memory config) external {
        if (msg.sender != AUTHORIZED) revert Deployer_Unauthorized();
        if (_deployed) revert Deployer_AlreadyDeployed();
        _deployed = true;

        bytes memory initializeCalldata = abi.encodeWithSelector(ICounter.initialize.selector, config.owner);
        counter = _createProxy(implementations.counter, initializeCalldata);

        emit Deploy(counter);
    }

    /// @notice Creates an ERC1967 proxy pointing to the given implementation
    /// @param proxyImplementation Address of the implementation contract
    /// @param initializeCalldata Encoded initializer call
    /// @return proxyAddress Address of the newly created proxy
    function _createProxy(address proxyImplementation, bytes memory initializeCalldata)
        internal
        returns (address proxyAddress)
    {
        proxyAddress = address(new ERC1967Proxy(proxyImplementation, initializeCalldata));
    }
}

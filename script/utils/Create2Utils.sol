// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Vm} from "forge-std/Vm.sol";

library Create2Utils {
    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address internal constant SAFE_SINGLETON_FACTORY = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;

    bytes internal constant SAFE_SINGLETON_FACTORY_BYTECODE =
        hex"7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3";


    /// @dev Uses vm.etch to deploy the factory in local/fork simulations.
    /// On live networks the factory must already exist at SAFE_SINGLETON_FACTORY.
    function loadCreate2Factory() internal {
        if (SAFE_SINGLETON_FACTORY.code.length == 0) {
            VM.etch(SAFE_SINGLETON_FACTORY, SAFE_SINGLETON_FACTORY_BYTECODE);
        }
    }

    function create2Deploy(bytes32 salt, bytes memory creationCode) internal returns (address deployed) {
        deployed = computeCreate2Address(salt, creationCode);
        if (deployed.code.length > 0) return deployed;
        (bool success, bytes memory result) = SAFE_SINGLETON_FACTORY.call(abi.encodePacked(salt, creationCode));
        require(success && result.length == 20, "Create2Utils: deployment failed");
        assembly {
            deployed := shr(96, mload(add(result, 0x20)))
        }
        require(deployed != address(0), "Create2Utils: deployment returned zero address");
    }

    function computeCreate2Address(bytes32 salt, bytes memory creationCode) internal pure returns (address) {
        return address(
            uint160(
                uint256(keccak256(abi.encodePacked(bytes1(0xff), SAFE_SINGLETON_FACTORY, salt, keccak256(creationCode))))
            )
        );
    }

    function computeSalt(string memory contractName, string memory version) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(contractName, version));
    }

    function computeSalt(string memory contractName, string memory envLabel, string memory version)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(contractName, envLabel, version));
    }
}

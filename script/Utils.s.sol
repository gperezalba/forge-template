// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

contract Utils is Script {
    using stdJson for string;

    function getAddressFromConfigJson(string memory key) public view returns (address) {
        string memory json = getConfigJson();
        bytes memory data = json.parseRaw(key);
        return abi.decode(data, (address));
    }

    function getConfigJson() public view returns (string memory) {
        return vm.readFile(getJsonConfigPath());
    }

    function getJsonConfigPath() public view returns (string memory) {
        string memory inputDir = string.concat(vm.projectRoot(), "/addresses/");
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory file = string.concat("config.json");
        return string.concat(inputDir, chainDir, file);
    }

    function address2String(address addr) public pure returns (string memory) {
        return vm.toString(addr);
    }

    // writeAddress2File("./addresses/", 1, "MyScript.txt", address(this));
    function writeAddress2File(string memory root, uint256 chainId, string memory fileName, address addr) public {
        string memory path = string(abi.encodePacked(root, vm.toString(chainId), "/", fileName));
        writeAddress2File(path, addr);
    }

    function writeAddress2File(string memory path, address addr) public {
        vm.writeFile(path, vm.toString(addr));
    }

    // readAddressFromFile("./addresses/", 1, "MyScript.txt")
    function readAddressFromFile(string memory path) public view returns (address) {
        string memory txt = vm.readLine(path);
        return _toAddress(txt);
    }

    function readAddressFromFile(string memory root, uint256 chainId, string memory fileName)
        public
        view
        returns (address)
    {
        string memory path = string(abi.encodePacked(root, vm.toString(chainId), "/", fileName));
        return readAddressFromFile(path);
    }

    function readAddressFromFile(string memory root, string memory fileName) public view returns (address) {
        string memory path = string(abi.encodePacked(root, "/", fileName));
        return readAddressFromFile(path);
    }

    function readStringFromFile(string memory path) public view returns (string memory) {
        return vm.readLine(path);
    }

    function readStringFromFile(string memory root, uint256 chainId, string memory fileName)
        public
        view
        returns (string memory)
    {
        string memory path = string(abi.encodePacked(root, vm.toString(chainId), "/", fileName));
        return vm.readLine(path);
    }

    function _toAddress(string memory s) internal pure returns (address) {
        bytes memory _bytes = _hexStringToAddress(s);
        require(_bytes.length >= 1 + 20, "toAddress_outOfBounds");
        address tempAddress;

        // solhint-disable-next-line
        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), 1)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }

    function _fromHexChar(uint8 c) internal pure returns (uint8) {
        if (bytes1(c) >= bytes1("0") && bytes1(c) <= bytes1("9")) {
            return c - uint8(bytes1("0"));
        }
        if (bytes1(c) >= bytes1("a") && bytes1(c) <= bytes1("f")) {
            return 10 + c - uint8(bytes1("a"));
        }
        if (bytes1(c) >= bytes1("A") && bytes1(c) <= bytes1("F")) {
            return 10 + c - uint8(bytes1("A"));
        }
        return 0;
    }

    function _hexStringToAddress(string memory s) internal pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length % 2 == 0, "length must be even");
        bytes memory r = new bytes(ss.length / 2);
        for (uint256 i = 0; i < ss.length / 2; ++i) {
            r[i] = bytes1(_fromHexChar(uint8(ss[2 * i])) * 16 + _fromHexChar(uint8(ss[2 * i + 1])));
        }

        return r;
    }
}

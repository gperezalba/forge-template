---
name: sol-scaffold
description: "[Solidity] Scaffold a new Foundry project from scratch with UUPS upgradeable contracts, CREATE2 deployments, and BTT testing infrastructure. Creates all config, deployment, and test files with zero example contracts."
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# Solidity — Scaffold New Project

Create the full Foundry project infrastructure from scratch. No example contracts — just the deployment pipeline, test infrastructure, and config files ready for `sol-add-contract` to add the first contract.

---

## Phase 0: Questions

Ask the user before doing anything:

1. **Project name** — used for `package.json` name and NatSpec `@author` (e.g. `my-protocol`)
2. **Solidity version** — default `0.8.24`
3. **Chains and environments** — e.g. "Sepolia DEV/INT/STA, Polygon PRO". Each combination gets its own Config and Deploy file.
4. **External tokens for EnvConfig?** — e.g. USDT, WETH — or none. These become fields in `EnvConfig` struct and per-chain config constants. If none, `EnvConfig` struct is empty.

---

## Phase 1: Config Files

### 1.1 `foundry.toml`

Replace `<SOLIDITY_VERSION>` with the user's answer. Replace `[rpc_endpoints]` and `[etherscan]` entries based on the chains the user chose.

```toml
[profile.default]
src = 'src'
out = 'out'
test = 'test'
libs = ['lib']

evm_version = 'cancun'
gas_reports = ['*']
solc_version = '<SOLIDITY_VERSION>'
auto_detect_solc = true
optimizer = true
optimizer_runs = 200

initial_balance = '0xffffffffffffffffffffffff'
block_number = 0
gas_limit = 1099511627776
gas_price = 0
block_base_fee_per_gas = 0
block_coinbase = '0x0000000000000000000000000000000000000000'
block_timestamp = 0
block_difficulty = 0

bytecode_hash = "none"

ignored_error_codes = []
fs_permissions = [{ access = "read-write", path = "./reports"}, { access = "read", path = "./package.json"}]

[profile.default.fuzz]
runs = 1000

[profile.ci.fuzz]
runs = 10000

[lint]
exclude_lints = ["unsafe-cheatcode", "mixed-case-function"]
ignore = ["test/**/*.t.sol", "test/**/*.sol", "script/**/*.s.sol", "src/utils/Deployer.sol"]

[rpc_endpoints]
# Add one per chain, e.g.:
# sepolia = "${RPC_SEPOLIA}"
# polygon = "${RPC_POLYGON}"

[etherscan]
# Add one per chain, e.g.:
# sepolia = { key = "${ETHERSCAN_API_KEY}", chainId = 11155111 }
# polygon = { key = "${ETHERSCAN_API_KEY}", chainId = 137 }
```

### 1.2 `package.json`

Replace `<PROJECT_NAME>` and `<AUTHOR>`. Add `deploy:<chain>:<env>` scripts for each chain/env combination (no single-deploy or workflow scripts — `sol-add-contract` adds those).

```json
{
  "name": "<PROJECT_NAME>",
  "version": "1.0.0",
  "description": "",
  "directories": {
    "lib": "lib",
    "test": "test"
  },
  "scripts": {
    "build": "forge build",
    "test": "npm run test:fork && npm run test:local",
    "test:local": "forge test --no-match-test testFork --gas-report -vvv",
    "test:fork": "source .env && forge test --match-test testFork --fork-url <named-endpoint> --gas-report -vvv",
    "test:fork:all": "source .env && forge test --fork-url <named-endpoint> --gas-report -vvv",
    "coverage": "source .env && forge coverage --fork-url <named-endpoint> --report lcov && lcov --remove lcov.info 'test/*' 'script/*' --output-file lcov.info --rc lcov_branch_coverage=1 && genhtml lcov.info -o report --branch-coverage && open report/index.html",
    "solhint:check": "npx solhint --max-warnings 0 --ignore-path .solhintignore 'src/**/*.sol'",
    "solhint:fix": "npx solhint --max-warnings 0 --ignore-path .solhintignore 'src/**/*.sol' --fix",
    "doc": "forge doc --out documentation",
    "doc-serve": "forge doc --serve --out documentation",
    "deploy:polygon": "source .env && export ENV=PRO && forge script script/deployment/DeployPolygon.s.sol:DeployPolygon --ffi --rpc-url polygon --private-key ${PRIVATE_KEY} --broadcast --slow -vvvv --verify --chain polygon",
    "deploy:sepolia:dev": "source .env && export ENV=DEV && forge script script/deployment/DeploySepoliaDEV.s.sol:DeploySepoliaDEV --ffi --rpc-url sepolia --private-key ${PRIVATE_KEY} --broadcast --slow -vvvv --verify --chain sepolia"
  },
  "author": "<AUTHOR>",
  "homepage": ""
}
```

**Note**: The deploy scripts shown above are examples for Sepolia DEV and Polygon PRO. Generate one per chain/env combination based on the user's answer. Replace `<named-endpoint>` in test:fork/coverage scripts with one of the chain aliases (typically the mainnet fork chain).

### 1.3 `.solhint.json`

Replace `<SOLIDITY_VERSION>` with the user's answer.

```json
{
    "extends": "solhint:recommended",
    "plugins": [],
    "rules": {
        "compiler-version": [
            "error",
            "><SOLIDITY_VERSION>"
        ],
        "func-visibility": [
            "warn",
            {
                "ignoreConstructors": true
            }
        ],
        "no-unused-vars": "error",
        "func-param-name-mixedcase": "error",
        "modifier-name-mixedcase": "error",
        "private-vars-leading-underscore": "error",
        "imports-on-top": "error",
        "quotes": [
            "error",
            "double"
        ],
        "import-path-check": "off"
    }
}
```

### 1.4 `remappings.txt`

```
@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
ds-test/=lib/forge-std/lib/ds-test/src/
erc4626-tests/=lib/openzeppelin-contracts-upgradeable/lib/erc4626-tests/
forge-std/=lib/forge-std/src/
```

### 1.5 `.env.example`

Add RPC vars based on the user's chains.

```
PRIVATE_KEY=0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc1

ETHERSCAN_API_KEY=

# Add one RPC var per chain:
# RPC_SEPOLIA=https://ethereum-sepolia-rpc.publicnode.com
# RPC_POLYGON=https://polygon-rpc.com
```

### 1.6 `.solhintignore`

```
node_modules
test/
script/
```

### 1.7 `.gitignore`

```
# Compiler files
cache/
out/*

!out/Contract.sol
!out/Contract.sol/Contract.json

# Ignores development and testnet broadcast logs
!/broadcast
/broadcast/*/31337/
/broadcast/*/11155111/
/broadcast/**/dry-run/

# Coverage
lcov.info
report/

# Dotenv file
.env

# Documentation
documentation/
```

---

## Phase 2: Core Utils

### 2.1 `src/utils/proxy/UUPSOwnable2Step.sol`

Replace `<SOLIDITY_VERSION>` and `<AUTHOR>`.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

//solhint-disable func-name-mixedcase
//solhint-disable no-empty-blocks

/// @title UUPSOwnable2Step
/// @author <AUTHOR>
/// @notice Implementation of UUPS proxy pattern with two-step ownership transfer
/// @dev Combines UUPSUpgradeable with Ownable2StepUpgradeable for secure upgradeable contracts
contract UUPSOwnable2Step is UUPSUpgradeable, Ownable2StepUpgradeable {
    /// @notice Initializes the contract
    /// @dev Empty initialization as core initialization is handled by parent contracts
    function __UUPSOwnable2Step_init() internal onlyInitializing {
        __UUPSOwnable2Step_init_unchained();
    }

    /// @notice Additional initialization logic (if needed in the future)
    /// @dev Empty initialization, maintained for potential future use
    function __UUPSOwnable2Step_init_unchained() internal onlyInitializing {}

    /// @notice Authorizes an upgrade to a new implementation
    /// @dev Can only be called by the owner
    /// @param newImplementation Address of the new implementation contract
    function _authorizeUpgrade(address newImplementation) internal view virtual override onlyOwner {}

    /// @notice Gets the address of the current implementation
    /// @dev Uses ERC1967Utils to retrieve the implementation address
    /// @return The address of the current implementation contract
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }
}
```

### 2.2 `src/utils/Deployer.sol`

Empty scaffold — no contract-specific logic. The `deployed()` getter enables idempotency checks from `DeployContracts`.

Replace `<SOLIDITY_VERSION>` and `<AUTHOR>`.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title Deployer
/// @author <AUTHOR>
/// @notice Deploys and initializes project proxies in a single transaction
contract Deployer {
    /// @notice Addresses of the contract implementations or proxies
    struct Addresses {
        // sol-add-contract will add fields here
    }

    /// @notice Configuration for the deployment
    struct Config {
        address owner;
    }

    /// @notice Address authorized to trigger the deployment
    address public immutable AUTHORIZED;

    /// @dev Whether the deployment has already been executed
    bool private _deployed;

    /// @notice Thrown when the caller is not the authorized deployer
    error Deployer_Unauthorized();

    /// @notice Thrown when deploy is called more than once
    error Deployer_AlreadyDeployed();

    /// @notice Emitted when the deployment is executed
    event Deploy();

    /// @notice Sets the authorized deployer to tx.origin (needed for CREATE2 factory deployment)
    constructor() {
        // solhint-disable-next-line avoid-tx-origin
        AUTHORIZED = tx.origin;
    }

    /// @notice Returns whether the deployment has been executed
    function deployed() external view returns (bool) {
        return _deployed;
    }

    /// @notice Deploys and initializes all project proxies
    /// @param implementations Addresses of the implementation contracts
    /// @param config Deployment configuration (owner, etc.)
    function deploy(Addresses calldata implementations, Config calldata config) external {
        // solhint-disable-next-line avoid-tx-origin
        if (tx.origin != AUTHORIZED) revert Deployer_Unauthorized();
        if (_deployed) revert Deployer_AlreadyDeployed();
        _deployed = true;

        // sol-add-contract will add proxy creation here

        emit Deploy();
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
```

### 2.3 `script/utils/Create2Utils.sol`

Replace `<SOLIDITY_VERSION>`.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

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
```

---

## Phase 3: Deployment Infrastructure

### 3.1 `script/deployment/misc/DeployBase.s.sol`

Replace `<SOLIDITY_VERSION>`.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

// solhint-disable

import {Script, console} from "forge-std/Script.sol";
import {ConfigAbstract} from "../config/ConfigAbstract.sol";
import {DeployContracts} from "./DeployContracts.sol";
import {DeployReport} from "./DeployReport.s.sol";

abstract contract DeployBase is ConfigAbstract, Script, DeployReport, DeployContracts {
    function run() external {
        console.log("PROJECT deployment");
        console.log("sender", msg.sender);
        ConfigAbstract.Config memory config = _getInitialConfig();
        _checkInitialConfig(config);
        string memory envLabel = _envLabel(config.env);
        string memory version = abi.decode(vm.parseJson(vm.readFile("package.json"), ".version"), (string));
        vm.startBroadcast();
        DeployContracts.Report memory deployReport = _deployContracts(config.deployerConfig, envLabel, version);
        vm.stopBroadcast();
        ConfigAbstract.EnvConfig memory envConfig = _getEnvConfig();
        console.log("Generate report");
        _writeJsonDeployReport(deployReport, config.env, envConfig);
        console.log("DONE");
    }

    function _checkInitialConfig(ConfigAbstract.Config memory config) internal pure {
        require(config.deployerConfig.owner != address(0), "config.owner is zero address");
    }

    function _envLabel(Environment env) internal pure returns (string memory) {
        if (env == Environment.DEV) return "DEV";
        if (env == Environment.INT) return "INT";
        return "PRO&STA";
    }
}
```

### 3.2 `script/deployment/misc/DeployContracts.sol`

Empty scaffold — no contract imports. `_deployImplementations` returns empty `Addresses`. `_deployDeployer` uses `deployer.deployed()` for idempotency.

Replace `<SOLIDITY_VERSION>`.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

// solhint-disable

import {Deployer} from "src/utils/Deployer.sol";
import {Create2Utils} from "script/utils/Create2Utils.sol";

contract DeployContracts {
    struct Report {
        Deployer.Config deployerConfig;
        Deployer.Addresses implementations;
        Deployer.Addresses proxies;
        address deployer;
    }

    function _deployContracts(Deployer.Config memory deployerConfig, string memory envLabel, string memory version)
        internal
        returns (Report memory deployReport)
    {
        Create2Utils.loadCreate2Factory();
        Deployer.Addresses memory implementations = _deployImplementations(version);
        (Deployer.Addresses memory proxies, Deployer deployer) =
            _deployDeployer(implementations, deployerConfig, envLabel, version);
        deployReport.deployerConfig = deployerConfig;
        deployReport.implementations = implementations;
        deployReport.proxies = proxies;
        deployReport.deployer = address(deployer);
        return deployReport;
    }

    function _deployImplementations(string memory version)
        internal
        returns (Deployer.Addresses memory implementations)
    {
        // sol-add-contract will add implementation deployments here
        return implementations;
    }

    function _deployDeployer(
        Deployer.Addresses memory implementations,
        Deployer.Config memory deployerConfig,
        string memory envLabel,
        string memory version
    ) internal returns (Deployer.Addresses memory proxies, Deployer deployer) {
        bytes32 salt = Create2Utils.computeSalt("Deployer", envLabel, version);
        deployer = Deployer(Create2Utils.create2Deploy(salt, type(Deployer).creationCode));
        if (!deployer.deployed()) {
            deployer.deploy(implementations, deployerConfig);
        }
        // sol-add-contract will add proxy reads here, e.g.:
        // proxies.<contractName> = deployer.<contractName>();
    }
}
```

### 3.3 `script/deployment/misc/DeployReport.s.sol`

Full code with `getTimestamp()` and `getGitModuleVersion()` FFI helpers. Proxies/implementations blocks use `vm.serializeString(key, "empty", "true")` as placeholder — `sol-add-contract` replaces these.

Replace `<SOLIDITY_VERSION>`. If the user chose tokens for `EnvConfig`, add them to the tokens block. If no tokens, use the placeholder there too.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

// solhint-disable

import {Script} from "forge-std/Script.sol";
import {DeployContracts} from "./DeployContracts.sol";
import {ConfigAbstract} from "../config/ConfigAbstract.sol";

contract DeployReport is Script {
    function _writeJsonDeployReport(
        DeployContracts.Report memory report,
        ConfigAbstract.Environment env,
        ConfigAbstract.EnvConfig memory envConfig
    ) internal {
        (string memory factoryV3Commit, string memory factoryV3Branch) = getGitModuleVersion();
        string memory jsonReport = "project-report";

        string memory githubOutput;
        string memory proxiesOutput;
        string memory impOutput;
        string memory tokensOutput;

        {
            string memory jsonGithub = "github";
            vm.serializeString(jsonGithub, "repository-commit", factoryV3Commit);
            githubOutput = vm.serializeString(jsonGithub, "repository-branch", factoryV3Branch);
        }
        //proxies
        {
            string memory jsonProxies = "proxies";
            proxiesOutput = vm.serializeString(jsonProxies, "empty", "true");
            // sol-add-contract: replace the line above with vm.serializeAddress for each proxy
        }
        //implementations
        {
            string memory jsonImplementations = "implementations";
            impOutput = vm.serializeString(jsonImplementations, "empty", "true");
            // sol-add-contract: replace the line above with vm.serializeAddress for each implementation
        }
        //tokens
        {
            string memory jsonTokens = "tokens";
            tokensOutput = vm.serializeString(jsonTokens, "empty", "true");
            // If EnvConfig has tokens, replace with:
            // tokensOutput = vm.serializeAddress(jsonTokens, "usdt", envConfig.usdt);
        }

        //general
        vm.serializeAddress(jsonReport, "owner", report.deployerConfig.owner);
        vm.serializeAddress(jsonReport, "deployer", report.deployer);
        vm.serializeString(jsonReport, "github", githubOutput);
        vm.serializeString(jsonReport, "proxies", proxiesOutput);
        vm.serializeString(jsonReport, "tokens", tokensOutput);
        string memory json = vm.serializeString(jsonReport, "implementations", impOutput);
        string memory environment = getEnvironmentFromEnum(env);
        vm.writeJson(
            json,
            string.concat(
                "./reports/", vm.toString(block.chainid), "/", environment, "/", getTimestamp(), "-deployment.json"
            )
        );
        vm.writeJson(
            json, string.concat("./reports/", vm.toString(block.chainid), "/", environment, "/latest-deployment.json")
        );
    }

    function getEnvironmentFromEnum(ConfigAbstract.Environment envEnum) public pure returns (string memory env) {
        if (envEnum == ConfigAbstract.Environment.DEV) return "DEV";
        if (envEnum == ConfigAbstract.Environment.INT) return "INT";
        if (envEnum == ConfigAbstract.Environment.STA) return "STA";
        if (envEnum == ConfigAbstract.Environment.PRO) return "PRO";
    }

    function getTimestamp() public returns (string memory result) {
        string[] memory command = new string[](3);

        command[0] = "bash";
        command[1] = "-c";
        command[2] = 'response="$(date +%s)"; cast abi-encode "response(string)" $response;';
        bytes memory timestamp = vm.ffi(command);
        (result) = abi.decode(timestamp, (string));

        return result;
    }

    function getGitModuleVersion() public returns (string memory commit, string memory branch) {
        string[] memory commitCommand = new string[](3);
        string[] memory branchCommand = new string[](3);

        commitCommand[0] = "bash";
        commitCommand[1] = "-c";
        commitCommand[2] = 'response="$(echo -n $(git rev-parse HEAD))"; cast abi-encode "response(string)" "$response"';

        bytes memory commitResponse = vm.ffi(commitCommand);

        (commit) = abi.decode(commitResponse, (string));

        branchCommand[0] = "bash";
        branchCommand[1] = "-c";
        branchCommand[2] =
            'response="$(echo -n $(git branch --show-current))"; cast abi-encode "response(string)" "$response"';

        bytes memory response = vm.ffi(branchCommand);

        (branch) = abi.decode(response, (string));

        return (commit, branch);
    }
}
```

**If the user chose tokens for EnvConfig**: Replace the tokens placeholder block with actual `vm.serializeAddress` calls. For example, if they chose USDT:

```solidity
        //tokens
        {
            string memory jsonTokens = "tokens";
            tokensOutput = vm.serializeAddress(jsonTokens, "usdt", envConfig.usdt);
        }
```

### 3.4 `script/deployment/config/ConfigAbstract.sol`

Replace `<SOLIDITY_VERSION>`. If the user chose tokens, add them to `EnvConfig`. If none, leave `EnvConfig` empty.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

// solhint-disable

import {Deployer} from "src/utils/Deployer.sol";

abstract contract ConfigAbstract {
    enum Environment {
        DEV,
        INT,
        STA,
        PRO
    }

    struct Config {
        Environment env;
        Deployer.Config deployerConfig;
    }

    struct EnvConfig {
        // sol-add-contract or user tokens go here
        // e.g.: address usdt;
    }

    function _getInitialConfig() internal virtual returns (Config memory config);
    function _getEnvConfig() internal view virtual returns (EnvConfig memory envConfig);
}
```

**If user chose tokens**: Add them as fields in `EnvConfig`. For example:

```solidity
    struct EnvConfig {
        address usdt;
    }
```

---

## Phase 4: Per-Chain Config

Create one `Config<Chain><Env>.sol` and one `Deploy<Chain><Env>.s.sol` per chain/environment combination.

### 4.1 `script/deployment/config/Config<Chain><Env>.sol`

Template — create one per combination. Replace `<SOLIDITY_VERSION>`, `<Chain><Env>`, `<ENV_ENUM>`.

Set `_OWNER` to a placeholder `address(0)` with a `// TODO: set owner address` comment. If user has tokens, add placeholders for each token address too.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

// solhint-disable

import {ConfigAbstract, Deployer} from "./ConfigAbstract.sol";

contract Config<Chain><Env> is ConfigAbstract {
    ConfigAbstract.Environment internal constant _ENV = ConfigAbstract.Environment.<ENV_ENUM>;
    address internal constant _OWNER = address(0); // TODO: set owner address

    function _getInitialConfig() internal pure override returns (Config memory config) {
        config.env = _ENV;
        config.deployerConfig = Deployer.Config({owner: _OWNER});
        return config;
    }

    function _getEnvConfig() internal pure override returns (EnvConfig memory envConfig) {
        return envConfig;
    }
}
```

**If user has tokens**: Add constants and populate `envConfig`. For example:

```solidity
    address internal constant _USDT = address(0); // TODO: set USDT address

    function _getEnvConfig() internal pure override returns (EnvConfig memory envConfig) {
        envConfig = EnvConfig({usdt: _USDT});
        return envConfig;
    }
```

**Examples of chain/env combinations**:
- `ConfigSepoliaDEV` with `Environment.DEV`
- `ConfigSepoliaINT` with `Environment.INT`
- `ConfigSepoliaSTA` with `Environment.STA`
- `ConfigPolygon` with `Environment.PRO` (production chains don't repeat the env in the name)

### 4.2 `script/deployment/Deploy<Chain><Env>.s.sol`

Template — create one per combination. Replace `<SOLIDITY_VERSION>`, `<Chain><Env>`.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

// solhint-disable

import {DeployBase} from "./misc/DeployBase.s.sol";
import {Config<Chain><Env>} from "./config/Config<Chain><Env>.sol";

contract Deploy<Chain><Env> is DeployBase, Config<Chain><Env> {}
```

---

## Phase 5: Single-Deploy Base

### `script/single-deployments/SingleDeployBase.s.sol`

Replace `<SOLIDITY_VERSION>`.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

// solhint-disable

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Create2Utils} from "script/utils/Create2Utils.sol";

abstract contract SingleDeployBase is Script {
    using stdJson for string;

    function _getVersion() internal view returns (string memory) {
        return abi.decode(vm.parseJson(vm.readFile("package.json"), ".version"), (string));
    }

    function _getEnv() internal view returns (string memory) {
        return vm.envString("ENV");
    }

    function _getReportPath(string memory env) internal view returns (string memory) {
        return string.concat("./reports/", vm.toString(block.chainid), "/", env, "/latest-deployment.json");
    }

    function _readAddressFromReport(string memory reportPath, string memory key) internal view returns (address) {
        string memory json = vm.readFile(reportPath);
        return abi.decode(json.parseRaw(key), (address));
    }

    function _writeAddressToReport(string memory reportPath, string memory key, address addr) internal {
        vm.writeJson(string.concat('"', vm.toString(addr), '"'), reportPath, key);
    }
}
```

---

## Phase 6: Workflows Base

### `script/Workflows.s.sol`

Just the `Ecosystem` base contract with `_getAddressFromReport()` helper. No workflow actions — `sol-add-contract` adds those.

Replace `<SOLIDITY_VERSION>`.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

// solhint-disable

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Deployer} from "src/utils/Deployer.sol";

contract Ecosystem is Script {
    using stdJson for string;

    Deployer public immutable DEPLOYER;

    constructor() {
        DEPLOYER = Deployer(_getAddressFromReport(".deployer"));
    }

    function _getAddressFromReport(string memory key) internal view returns (address) {
        string memory env = vm.envString("ENV");
        string memory path =
            string.concat("./reports/", vm.toString(block.chainid), "/", env, "/latest-deployment.json");
        string memory json = vm.readFile(path);
        bytes memory data = json.parseRaw(key);
        return abi.decode(data, (address));
    }
}
```

---

## Phase 7: Test Infrastructure

### 7.1 `test/Base.t.sol`

No contract-specific labels. Replace `<SOLIDITY_VERSION>`. If user has tokens, include the mock.

**With tokens (e.g. USDT)**:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

// solhint-disable

import {Test} from "forge-std/Test.sol";

import {DeployContracts} from "script/deployment/misc/DeployContracts.sol";
import {ConfigAbstract, Deployer} from "script/deployment/config/ConfigAbstract.sol";

import {ERC20Mock} from "./mocks/ERC20Mock.sol";

contract Base is Test, DeployContracts, ConfigAbstract {
    // Test accounts
    address public owner = makeAddr("owner");
    address public nonOwner = makeAddr("nonOwner");

    // Deployed system
    DeployContracts.Report public deployReport;

    // Mock tokens
    ERC20Mock public mockUsdt = new ERC20Mock("Test USDT", "TUSDT", 6);

    function setUp() public virtual {
        vm.label(address(mockUsdt), "mockUsdt");

        // Deploy contracts
        _deployProjectContracts();

        vm.label(deployReport.deployer, "deployer");
        // sol-add-contract will add implementation labels here
    }

    function _deployProjectContracts() internal {
        Config memory config = _getInitialConfig();
        string memory version = abi.decode(vm.parseJson(vm.readFile("package.json"), ".version"), (string));
        deployReport = _deployContracts(config.deployerConfig, "DEV", version);
    }

    function _getInitialConfig() internal view override returns (Config memory config) {
        config.env = Environment.DEV;
        config.deployerConfig = Deployer.Config({owner: owner});
        return config;
    }

    function _getEnvConfig() internal view override returns (EnvConfig memory envConfig) {
        envConfig = EnvConfig({usdt: address(mockUsdt)});
        return envConfig;
    }
}
```

**Without tokens** (empty EnvConfig):

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

// solhint-disable

import {Test} from "forge-std/Test.sol";

import {DeployContracts} from "script/deployment/misc/DeployContracts.sol";
import {ConfigAbstract, Deployer} from "script/deployment/config/ConfigAbstract.sol";

contract Base is Test, DeployContracts, ConfigAbstract {
    // Test accounts
    address public owner = makeAddr("owner");
    address public nonOwner = makeAddr("nonOwner");

    // Deployed system
    DeployContracts.Report public deployReport;

    function setUp() public virtual {
        // Deploy contracts
        _deployProjectContracts();

        vm.label(deployReport.deployer, "deployer");
        // sol-add-contract will add implementation labels here
    }

    function _deployProjectContracts() internal {
        Config memory config = _getInitialConfig();
        string memory version = abi.decode(vm.parseJson(vm.readFile("package.json"), ".version"), (string));
        deployReport = _deployContracts(config.deployerConfig, "DEV", version);
    }

    function _getInitialConfig() internal view override returns (Config memory config) {
        config.env = Environment.DEV;
        config.deployerConfig = Deployer.Config({owner: owner});
        return config;
    }

    function _getEnvConfig() internal view override returns (EnvConfig memory envConfig) {
        return envConfig;
    }
}
```

### 7.2 `test/mocks/ERC20Mock.sol`

Only create this if user chose tokens for EnvConfig. Replace `<SOLIDITY_VERSION>`.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

// solhint-disable

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
```

### 7.3 `test/integration/SafeSingletonFactory.t.sol`

Replace `<SOLIDITY_VERSION>`.

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

// solhint-disable

import {Test} from "forge-std/Test.sol";

import {Create2Utils} from "script/utils/Create2Utils.sol";

/// @dev Integration tests that run against a forked network.
/// All function names must contain "testFork" so they are picked up
/// by `npm run test:fork` (--match-test testFork) and excluded from
/// `npm run test:local` (--no-match-test testFork).
contract SafeSingletonFactoryForkTest is Test {
    function testFork_SafeSingletonFactoryIsDeployed() external {
        uint256 codeSize = Create2Utils.SAFE_SINGLETON_FACTORY.code.length;
        assertGt(codeSize, 0, "SafeSingletonFactory should be deployed on the forked network");
    }
}
```

---

## Phase 8: Directory Placeholders

Create `.gitkeep` files to ensure empty directories are tracked by git:

```bash
mkdir -p src/interfaces && touch src/interfaces/.gitkeep
mkdir -p reports && touch reports/.gitkeep
```

---

## Phase 9: Install Dependencies

```bash
forge install OpenZeppelin/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
```

If dependencies already exist (e.g. in `lib/`), skip this step.

---

## Phase 10: Validate

```bash
# Build must compile clean
forge build

# Local tests must pass (no fork tests yet since there's nothing to fork-test beyond SafeSingletonFactory)
npm run test:local
```

If build fails, fix compilation errors. Common issues:
- Missing import
- `EnvConfig` struct fields don't match between `ConfigAbstract` and the config files
- `DeployReport` references `envConfig` fields that don't exist

---

## Summary of Files Created

| Phase | Files |
|-------|-------|
| 1 | `foundry.toml`, `package.json`, `.solhint.json`, `remappings.txt`, `.env.example`, `.solhintignore`, `.gitignore` |
| 2 | `src/utils/proxy/UUPSOwnable2Step.sol`, `src/utils/Deployer.sol`, `script/utils/Create2Utils.sol` |
| 3 | `script/deployment/misc/DeployBase.s.sol`, `script/deployment/misc/DeployContracts.sol`, `script/deployment/misc/DeployReport.s.sol`, `script/deployment/config/ConfigAbstract.sol` |
| 4 | `script/deployment/config/Config<Chain><Env>.sol` x N, `script/deployment/Deploy<Chain><Env>.s.sol` x N |
| 5 | `script/single-deployments/SingleDeployBase.s.sol` |
| 6 | `script/Workflows.s.sol` |
| 7 | `test/Base.t.sol`, `test/mocks/ERC20Mock.sol` (if tokens), `test/integration/SafeSingletonFactory.t.sol` |
| 8 | `src/interfaces/.gitkeep`, `reports/.gitkeep` |

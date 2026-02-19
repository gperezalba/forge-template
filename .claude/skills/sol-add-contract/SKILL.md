---
name: sol-add-contract
description: "[Solidity] Add a new smart contract to the Foundry project deployment pipeline. Creates contract, interface, updates Deployer, DeployContracts, DeployReport, Workflows, test bases, and single-deployment scripts."
argument-hint: "<ContractName>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Solidity — Add Contract to Project

Add a new Solidity contract named `$ARGUMENTS` to the full deployment pipeline.

**Input**: `$ARGUMENTS` — the PascalCase contract name (e.g. `Vault`, `Token`, `Registry`)

---

## Phase 1: Questions

Before doing anything, ask the user:

1. **What does the contract do?** (brief description for NatSpec `@notice`)
2. **What parameters does `initialize()` need beyond `owner`?** (e.g. `address token`, `uint256 cap`). If only `owner`, say so.
3. **Should I create the contract and interface with placeholder logic, or do you already have the code?**
4. **Do you want workflow scripts for this contract?** If yes, which admin functions? (e.g. `pause`, `setConfig`)

---

## Phase 2: Contract & Interface

### Create `src/interfaces/I<ContractName>.sol`

Follow the existing pattern from `ICounter.sol`:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

/// @title I<ContractName>
/// @author gperezalba
/// @notice Interface for the <ContractName> contract
interface I<ContractName> {
    /// @notice Thrown when the provided address is the zero address
    error <ContractName>_ZeroAddress();

    // Add custom errors here

    /// @notice Initializes the contract with the given owner
    /// @param owner_ Address of the contract owner
    function initialize(address owner_) external;

    // Add external function signatures here
}
```

### Create `src/<ContractName>.sol`

Follow the existing pattern from `Counter.sol`:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {UUPSOwnable2Step} from "src/utils/proxy/UUPSOwnable2Step.sol";
import {I<ContractName>} from "src/interfaces/I<ContractName>.sol";

/// @title <ContractName>
/// @author gperezalba
/// @notice <description from Phase 1>
contract <ContractName> is UUPSOwnable2Step, I<ContractName> {
    /// @notice Initializes the contract setting the owner and upgradeability
    /// @param owner_ Address of the contract owner
    function initialize(address owner_) public initializer {
        if (owner_ == address(0)) revert <ContractName>_ZeroAddress();

        __Ownable_init(owner_);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
        __UUPSOwnable2Step_init();
    }
}
```

If the user provided extra init params, adjust `initialize()`, `Deployer.Config`, and the interface accordingly.

---

## Phase 3: Update Deployer (`src/utils/Deployer.sol`)

### 3.1 Add to `Addresses` struct

```solidity
struct Addresses {
    address counter;
    address <contractName>;  // ← ADD (camelCase)
}
```

### 3.2 Add public state variable

```solidity
/// @notice Address of the deployed <ContractName> proxy
address public <contractName>;
```

### 3.3 Add to `Config` struct (only if extra init params beyond owner)

If the contract needs init params beyond `owner`, add them to `Config`:

```solidity
struct Config {
    address owner;
    address <paramName>;  // ← ADD if needed
}
```

### 3.4 Add to `deploy()` function

Add the proxy creation BEFORE the `emit Deploy(...)`:

```solidity
// <ContractName>
bytes memory <contractName>InitCalldata = abi.encodeWithSelector(I<ContractName>.initialize.selector, config.owner);
<contractName> = _createProxy(implementations.<contractName>, <contractName>InitCalldata);
```

If extra init params exist, include them in the selector encoding.

### 3.5 Update `Deploy` event

Add the new address to the event:

```solidity
event Deploy(address indexed counter, address indexed <contractName>);
```

Update the `emit Deploy(...)` call accordingly.

### 3.6 Add import

```solidity
import {I<ContractName>} from "src/interfaces/I<ContractName>.sol";
```

---

## Phase 4: Update DeployContracts (`script/deployment/misc/DeployContracts.sol`)

### 4.1 Add import

```solidity
import {<ContractName>} from "src/<ContractName>.sol";
```

### 4.2 Add to `_deployImplementations()`

```solidity
bytes32 <contractName>Salt = Create2Utils.computeSalt("<ContractName>", version);
implementations.<contractName> = Create2Utils.create2Deploy(<contractName>Salt, type(<ContractName>).creationCode);
```

### 4.3 Add to `_deployDeployer()` (proxy read)

After the `deployer.deploy(...)` call, read the new proxy address:

```solidity
proxies.<contractName> = deployer.<contractName>();
```

Also add the `deployer.<contractName>() == address(0)` check if the existing pattern checks a specific contract (currently it checks `deployer.counter()`). If adding the first extra contract, the existing check is fine — but if the Deployer's `_deployed` guard is the real protection, no additional check is needed.

---

## Phase 5: Update DeployReport (`script/deployment/misc/DeployReport.s.sol`)

### 5.1 Add to proxies serialization block

```solidity
{
    string memory jsonProxies = "proxies";
    vm.serializeAddress(jsonProxies, "counter", report.proxies.counter);
    proxiesOutput = vm.serializeAddress(jsonProxies, "<contractName>", report.proxies.<contractName>);
}
```

**Important**: The LAST `vm.serializeAddress` in each block must be assigned to the output variable. Move the assignment to the new line.

### 5.2 Add to implementations serialization block

```solidity
{
    string memory jsonImplementations = "implementations";
    vm.serializeAddress(jsonImplementations, "counter", report.implementations.counter);
    impOutput = vm.serializeAddress(jsonImplementations, "<contractName>", report.implementations.<contractName>);
}
```

Same rule: last line gets the assignment.

---

## Phase 6: Update Test Base (`test/Base.t.sol`)

### 6.1 Add label in `setUp()`

```solidity
vm.label(deployReport.implementations.<contractName>, "<contractName>Impl");
```

### 6.2 Create `test/<ContractName>Base.t.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Base} from "./Base.t.sol";

import {<ContractName>} from "src/<ContractName>.sol";

contract <ContractName>Base is Base {
    // Contract instance for easy access
    <ContractName> public <contractName>;

    function setUp() public virtual override {
        super.setUp();
        <contractName> = <ContractName>(deployReport.proxies.<contractName>);
        vm.label(address(<contractName>), "<contractName>Proxy");
    }
}
```

---

## Phase 7: Create Single-Deployment Script (`script/single-deployments/<ContractName>.s.sol`)

Follow the pattern from `Counter.s.sol`:

```solidity
// SPDX-License-Identifier: UNLICENSED
// solhint-disable
pragma solidity 0.8.24;

import {console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {<ContractName>} from "src/<ContractName>.sol";
import {I<ContractName>} from "src/interfaces/I<ContractName>.sol";
import {Create2Utils} from "script/utils/Create2Utils.sol";
import {SingleDeployBase} from "./SingleDeployBase.s.sol";

/// @notice Deploys a new <ContractName> implementation via CREATE2 and updates the report
contract Deploy<ContractName>Implementation is SingleDeployBase {
    function run() external {
        string memory version = _getVersion();
        string memory env = _getEnv();
        string memory reportPath = _getReportPath(env);

        console.log("Deploying <ContractName> implementation");
        console.log("Version:", version);
        console.log("Environment:", env);

        vm.startBroadcast();
        Create2Utils.loadCreate2Factory();
        bytes32 salt = Create2Utils.computeSalt("<ContractName>", version);
        address implementation = Create2Utils.create2Deploy(salt, type(<ContractName>).creationCode);
        vm.stopBroadcast();

        console.log("<ContractName> implementation:", implementation);

        _writeAddressToReport(reportPath, ".implementations.<contractName>", implementation);

        console.log("DONE");
    }
}

/// @notice Deploys a new <ContractName> implementation and an ERC1967 proxy pointing to it, then updates the report
contract Deploy<ContractName>Proxy is SingleDeployBase {
    function run() external {
        string memory version = _getVersion();
        string memory env = _getEnv();
        string memory reportPath = _getReportPath(env);
        address owner = _readAddressFromReport(reportPath, ".owner");

        console.log("Deploying <ContractName> implementation + proxy");
        console.log("Version:", version);
        console.log("Environment:", env);
        console.log("Owner:", owner);

        vm.startBroadcast();
        Create2Utils.loadCreate2Factory();
        bytes32 salt = Create2Utils.computeSalt("<ContractName>", version);
        address implementation = Create2Utils.create2Deploy(salt, type(<ContractName>).creationCode);

        bytes memory initializeCalldata = abi.encodeWithSelector(I<ContractName>.initialize.selector, owner);
        address proxy = address(new ERC1967Proxy(implementation, initializeCalldata));
        vm.stopBroadcast();

        console.log("<ContractName> implementation:", implementation);
        console.log("<ContractName> proxy:", proxy);

        _writeAddressToReport(reportPath, ".implementations.<contractName>", implementation);
        _writeAddressToReport(reportPath, ".proxies.<contractName>", proxy);

        console.log("DONE");
    }
}
```

---

## Phase 8: Update Workflows (`script/Workflows.s.sol`) — if requested

### 8.1 Add import and immutable to `Ecosystem`

```solidity
import {<ContractName>} from "src/<ContractName>.sol";

// In Ecosystem contract:
<ContractName> public immutable <CONTRACTNAME>;  // UPPER_CASE for immutable

// In constructor:
<CONTRACTNAME> = <ContractName>(_getAddressFromReport(".proxies.<contractName>"));
```

### 8.2 Add workflow contracts

For each admin function the user requested:

```solidity
contract <ContractName><Action> is Ecosystem {
    function run() external {
        vm.startBroadcast();
        <CONTRACTNAME>.<action>(<params>);
        vm.stopBroadcast();
    }
}
```

---

## Phase 9: Add npm scripts to `package.json`

### Single-deployment scripts

```json
"deploy:<contractName>:impl:sepolia": "source .env && forge script script/single-deployments/<ContractName>.s.sol:Deploy<ContractName>Implementation --ffi --rpc-url sepolia --private-key ${PRIVATE_KEY} --broadcast --slow -vvvv --verify --chain sepolia",
"deploy:<contractName>:impl:sepolia:dev": "export ENV=DEV && npm run deploy:<contractName>:impl:sepolia",
"deploy:<contractName>:impl:sepolia:sta": "export ENV=STA && npm run deploy:<contractName>:impl:sepolia",
"deploy:<contractName>:impl:sepolia:int": "export ENV=INT && npm run deploy:<contractName>:impl:sepolia",
"deploy:<contractName>:impl:polygon": "source .env && export ENV=PRO && forge script script/single-deployments/<ContractName>.s.sol:Deploy<ContractName>Implementation --ffi --rpc-url polygon --private-key ${PRIVATE_KEY} --broadcast --slow -vvvv --verify --chain polygon",
"deploy:<contractName>:proxy:sepolia": "source .env && forge script script/single-deployments/<ContractName>.s.sol:Deploy<ContractName>Proxy --ffi --rpc-url sepolia --private-key ${PRIVATE_KEY} --broadcast --slow -vvvv --verify --chain sepolia",
"deploy:<contractName>:proxy:sepolia:dev": "export ENV=DEV && npm run deploy:<contractName>:proxy:sepolia",
"deploy:<contractName>:proxy:sepolia:sta": "export ENV=STA && npm run deploy:<contractName>:proxy:sepolia",
"deploy:<contractName>:proxy:sepolia:int": "export ENV=INT && npm run deploy:<contractName>:proxy:sepolia",
"deploy:<contractName>:proxy:polygon": "source .env && export ENV=PRO && forge script script/single-deployments/<ContractName>.s.sol:Deploy<ContractName>Proxy --ffi --rpc-url polygon --private-key ${PRIVATE_KEY} --broadcast --slow -vvvv --verify --chain polygon"
```

### Workflow scripts (if applicable)

```json
"<contractName>:<action>:sepolia": "source .env && forge script script/Workflows.s.sol:<ContractName><Action> --rpc-url sepolia --private-key ${PRIVATE_KEY} --broadcast --slow -vvvv",
"<contractName>:<action>:sepolia:dev": "export ENV=DEV && npm run <contractName>:<action>:sepolia",
"<contractName>:<action>:sepolia:sta": "export ENV=STA && npm run <contractName>:<action>:sepolia",
"<contractName>:<action>:sepolia:int": "export ENV=INT && npm run <contractName>:<action>:sepolia"
```

---

## Phase 10: Validate

```bash
# Build must compile clean
forge build

# Existing tests must still pass
npm run test:local
```

If build fails, fix compilation errors before finishing. Common issues:
- Missing import in a file
- Struct field order mismatch
- Deployer event signature changed but emit call not updated

---

## Summary of files touched/created

| Action | File |
|--------|------|
| Create | `src/<ContractName>.sol` |
| Create | `src/interfaces/I<ContractName>.sol` |
| Edit | `src/utils/Deployer.sol` (Addresses, Config, deploy(), event, import) |
| Edit | `script/deployment/misc/DeployContracts.sol` (import, _deployImplementations, _deployDeployer) |
| Edit | `script/deployment/misc/DeployReport.s.sol` (proxies + implementations serialization) |
| Edit | `test/Base.t.sol` (label) |
| Create | `test/<ContractName>Base.t.sol` |
| Create | `script/single-deployments/<ContractName>.s.sol` |
| Edit | `script/Workflows.s.sol` (if workflows requested) |
| Edit | `package.json` (npm scripts) |

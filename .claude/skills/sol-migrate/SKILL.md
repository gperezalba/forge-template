---
name: sol-migrate
description: "[Solidity] Migrate an existing Foundry/Solidity project to the forge-template structure. Interactive process that asks questions at each phase before making changes."
argument-hint: "<path-to-project>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Solidity — Migrate Existing Foundry Project

Migrate the Foundry/Solidity project at `$ARGUMENTS` to match the forge-template structure.

**Golden rule**: Never modify contract logic in `src/` unless explicitly requested. This guide restructures infrastructure (scripts, tests, config, directory layout), not business logic.

---

## Pre-Migration: Discovery

Read these files from the target project (if they exist):

1. `foundry.toml` — compiler settings, remappings, rpc endpoints
2. `package.json` — npm scripts, dependencies
3. `remappings.txt` — import path mappings
4. `.solhint.json` — linting rules
5. Any `README.md` or docs

Then explore:
- `src/` — list all contracts, check if upgradeable, identify proxy pattern
- `script/` — list all scripts, understand what they do
- `test/` — list all tests, identify structure (flat, by contract, by type)
- `lib/` — list dependencies

### Ask the user

Present your findings and ask:

1. **Confirm contract list**: "I found these contracts: [list]. Are these all the production contracts?"
2. **Upgradeability**: "These contracts use [pattern]. Should I migrate to UUPS or keep the current pattern?"
3. **Chains/environments**: "What chains and environments does this project target? (e.g. Sepolia DEV/INT/STA, Polygon PRO)"

---

## Phase 1: Project Configuration

### Ask before proceeding

> "I'm going to update project configuration files (foundry.toml, package.json, .solhint.json, remappings.txt). Should I replace or merge with existing configs?"

### 1.1 `foundry.toml`

Ensure these settings exist (merge or replace based on answer):

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "<project's solidity version>"
ffi = true
fs_permissions = [{ access = "read-write", path = "./" }]

[rpc_endpoints]
# one per chain the project uses

[etherscan]
# one per chain for verification

[fuzz]
runs = 1000

[invariant]
runs = 256
depth = 50
```

### 1.2 `package.json`

Create or extend with standard npm scripts:

```json
{
  "scripts": {
    "build": "forge build",
    "test": "npm run test:fork && npm run test:local",
    "test:local": "forge test --no-match-test testFork --gas-report -vvv",
    "test:fork": "source .env && forge test --match-test testFork --fork-url <chain> --gas-report -vvv",
    "test:fork:all": "source .env && forge test --fork-url <chain> --gas-report -vvv",
    "coverage": "source .env && forge coverage --fork-url <chain> --report lcov && lcov --remove lcov.info 'test/*' 'script/*' --output-file lcov.info --rc lcov_branch_coverage=1 && genhtml lcov.info -o report --branch-coverage && open report/index.html",
    "solhint:check": "npx solhint --max-warnings 0 --ignore-path .solhintignore 'src/**/*.sol'",
    "solhint:fix": "npx solhint --max-warnings 0 --ignore-path .solhintignore 'src/**/*.sol' --fix",
    "doc": "forge doc --out documentation",
    "doc-serve": "forge doc --serve --out documentation"
  }
}
```

### 1.3 `.solhint.json`

If the user wants the template's rules:

```json
{
  "extends": "solhint:recommended",
  "plugins": [],
  "rules": {
    "compiler-version": ["error", "0.8.24"],
    "func-visibility": ["error", { "ignoreConstructors": true }],
    "private-vars-leading-underscore": ["error"],
    "func-param-name-mixedcase": ["error"],
    "modifier-name-mixedcase": ["error"],
    "use-forbidden-name": ["error"],
    "quotes": ["error", "double"],
    "no-global-import": ["error"],
    "import-path-check": ["off"]
  }
}
```

### 1.4 `remappings.txt`

Update import remappings:

```
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/
```

### 1.5 Dependencies

Check and install if missing:

```bash
forge install OpenZeppelin/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
```

---

## Phase 2: Source Structure (`src/`)

**Reminder**: Do NOT modify contract logic unless explicitly asked.

### Ask before proceeding

1. **Interfaces**: "Should I extract interfaces from contracts into `src/interfaces/`? This means defining errors, events, and external function signatures in `I<Contract>.sol`."
2. **UUPSOwnable2Step**: "Should I copy the `UUPSOwnable2Step` base contract into `src/utils/proxy/`?"
3. **Deployer**: "Should I create a `Deployer` contract in `src/utils/` that deploys all proxies atomically?"

### Actions based on answers

**If extracting interfaces**:
- For each contract, create `src/interfaces/I<ContractName>.sol` with:
  - All custom errors (move from contract to interface)
  - All events (move from contract to interface)
  - All external function signatures
- Update contracts to `import {I<ContractName>}` and `is I<ContractName>`

**If adopting UUPS**:
- Copy `UUPSOwnable2Step.sol` from the template
- Each contract should inherit `UUPSOwnable2Step, I<ContractName>`
- Ensure `initialize()` exists with standard init chain
- Ensure `_authorizeUpgrade()` is `onlyOwner`

**Directory structure after**:

```
src/
├── ContractA.sol
├── ContractB.sol
├── interfaces/
│   ├── IContractA.sol
│   └── IContractB.sol
└── utils/
    ├── Deployer.sol
    └── proxy/
        └── UUPSOwnable2Step.sol
```

After restructuring, run `forge build` to verify compilation.

---

## Phase 3: Deployment Scripts

### Ask before proceeding

> "Which deployment style do you want?"
>
> 1. **Full Deployer** — atomic factory deploys all contracts in one tx (recommended for new setups)
> 2. **Single scripts only** — one script per contract, independent deploys
> 3. **Keep original** — don't change existing deployment scripts

Also ask:
- "Do you want CREATE2 deterministic addresses?"
- "Do you want a deployment report system (JSON file tracking all deployed addresses)?"

### If Full Deployer

Create the full infrastructure:

```
script/
├── deployment/
│   ├── Deploy<Chain><Env>.s.sol
│   ├── config/
│   │   ├── ConfigAbstract.sol
│   │   └── Config<Chain><Env>.sol
│   └── misc/
│       ├── DeployBase.s.sol
│       ├── DeployContracts.sol
│       └── DeployReport.s.sol
├── single-deployments/
│   ├── SingleDeployBase.s.sol
│   └── <ContractName>.s.sol
└── utils/
    └── Create2Utils.sol
```

For each file, follow the exact patterns from the template:

**ConfigAbstract.sol**: Define `Environment` enum, `Config` struct (with `Deployer.Config`), `EnvConfig` struct

**Config<Chain><Env>.sol**: Implement `_getInitialConfig()` and `_getEnvConfig()` with hardcoded addresses

**DeployBase.s.sol**: Inherit ConfigAbstract + Script + DeployReport + DeployContracts. Implement `run()` that loads config → validates → broadcasts → deploys → writes report

**DeployContracts.sol**: Define `Report` struct. Implement `_deployContracts()`, `_deployImplementations()`, `_deployDeployer()`

**DeployReport.s.sol**: Implement `_writeJsonDeployReport()` that serializes all addresses to JSON

**Deployer.sol**: Define `Addresses` struct, `Config` struct, `deploy()` function with `_createProxy()` calls for each contract

**Deploy<Chain><Env>.s.sol**: Empty contract inheriting DeployBase + Config<Chain><Env>

For each contract, create single-deployment scripts following the `Counter.s.sol` pattern.

Add npm scripts to `package.json` for each chain/env combination.

### If Single scripts only

Create `script/single-deployments/` with `SingleDeployBase.s.sol` and one script per contract.

### If keeping original

Skip this phase. Only add upgrade/workflow scripts if desired.

---

## Phase 4: Upgrade Scripts

### Ask before proceeding

> "Do any contracts need upgrade scripts? Should I create the upgrade infrastructure?"

### If yes

```
script/upgrades/
├── Upgrade<ContractName>.s.sol
└── storage-check/
    └── <ContractName>.s.sol
```

Each upgrade script reads the proxy from the report, deploys a new implementation, and calls `upgradeToAndCall`.

---

## Phase 5: Workflow Scripts

### Ask before proceeding

> "Are there admin functions that need workflow scripts for testnet? (pause, setConfig, grantRole, etc.)"

### If yes

Create `script/Workflows.s.sol` with:

```solidity
contract Ecosystem is Script {
    using stdJson for string;

    ContractA public immutable CONTRACT_A;
    // ... one immutable per contract

    constructor() {
        CONTRACT_A = ContractA(_getAddressFromReport(".proxies.contractA"));
    }

    function _getAddressFromReport(string memory key) internal view returns (address) {
        string memory env = vm.envString("ENV");
        string memory path = string.concat("./reports/", vm.toString(block.chainid), "/", env, "/latest-deployment.json");
        string memory json = vm.readFile(path);
        bytes memory data = json.parseRaw(key);
        return abi.decode(data, (address));
    }
}

// One contract per action
contract ContractAPause is Ecosystem {
    function run() external {
        vm.startBroadcast();
        CONTRACT_A.pause();
        vm.stopBroadcast();
    }
}
```

Add npm scripts: `<contractName>:<action>:sepolia:dev`, etc.

---

## Phase 6: Test Structure

### Ask before proceeding

1. > "Do you want to adopt BTT (Branching Tree Technique) for unit tests?"
   > - Yes → write `.tree` specs, scaffold with bulloak, implement
   > - No → restructure into directory layout but keep free-form style

2. > "Should I create `.tree` files for existing test coverage or start fresh?"
   > - Reverse-engineer from existing tests
   > - Start fresh (write new `.tree` files)
   > - Keep existing tests as-is, only add `.tree` for new functions

3. > "Do existing tests have a shared fixture/base, or does each test deploy its own contracts?"

### Step 6.1: Create `test/Base.t.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Test} from "forge-std/Test.sol";
import {DeployContracts} from "script/deployment/misc/DeployContracts.sol";
import {ConfigAbstract, Deployer} from "script/deployment/config/ConfigAbstract.sol";

contract Base is Test, DeployContracts, ConfigAbstract {
    address public owner = makeAddr("owner");
    address public nonOwner = makeAddr("nonOwner");

    DeployContracts.Report public deployReport;

    function setUp() public virtual {
        _deployProjectContracts();
        // Add vm.label for each implementation
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
        // Return mock addresses for testing
        return envConfig;
    }
}
```

### Step 6.2: Create `test/<ContractName>Base.t.sol` for each contract

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Base} from "./Base.t.sol";
import {ContractA} from "src/ContractA.sol";

contract ContractABase is Base {
    ContractA public contractA;

    function setUp() public virtual override {
        super.setUp();
        contractA = ContractA(deployReport.proxies.contractA);
        vm.label(address(contractA), "contractAProxy");
    }
}
```

### Step 6.3: Restructure test directories

```
test/
├── Base.t.sol
├── <ContractName>Base.t.sol
├── unit/<ContractName>/
│   ├── functionName.tree      (if BTT)
│   └── functionName.t.sol
├── integration/
├── invariant/
│   └── handlers/
├── fuzz/
├── fork/
└── mocks/
```

### Step 6.4: Migrate existing tests

- Move unit tests to `test/unit/<ContractName>/`
- Update inheritance to use `<ContractName>Base` instead of per-test deployments
- Rename test functions to match conventions: `test_`, `testFuzz_`, `testFork_`, `test_RevertWhen_`, `test_EmitWhen_`, `invariant_`
- Move fork tests to `test/fork/` and ensure function names contain `testFork`
- Move integration tests to `test/integration/`

### Step 6.5: If adopting BTT

For each function, use the `/btt` skill or manually:
1. Create `.tree` file
2. `bulloak scaffold -w -s <version> <path>`
3. Implement

---

## Phase 7: Reports Directory

### If deployment report was chosen

```
reports/
└── <chainId>/
    └── <env>/
        └── latest-deployment.json
```

Ask: "Are there existing deployed addresses that should be imported into the first report?"

If yes, create `latest-deployment.json` with current state:

```json
{
  "owner": "0x...",
  "deployer": "0x...",
  "proxies": { ... },
  "implementations": { ... },
  "tokens": { ... }
}
```

---

## Phase 8: Documentation

### Ask before proceeding

> "Do you want to copy the template's documentation to the project? (docs/solidity/ + CLAUDE.md)"

### If yes

- Create `docs/solidity/` with adapted versions of the template docs
- Create `docs/INDEX.md`
- Create `CLAUDE.md` at root with project-specific commands, architecture, gotchas, and references

---

## Phase 9: Validation

After all phases:

```bash
# 1. Build compiles clean
forge build

# 2. All tests pass
npm run test:local

# 3. Linting passes (if adopted)
npm run solhint:check

# 4. Formatting
forge fmt --check

# 5. BTT sync (if adopted)
bulloak check test/unit/**/*.tree
```

Fix any issues. Report results to the user.

---

## Migration Checklist

Present this to the user at the end:

| Phase | Item | Status |
|-------|------|--------|
| 1 | `foundry.toml` updated | |
| 1 | `package.json` with npm scripts | |
| 1 | `.solhint.json` configured | |
| 1 | `remappings.txt` updated | |
| 1 | Dependencies installed | |
| 2 | `src/` restructured (interfaces, utils) | |
| 2 | Proxy pattern aligned | |
| 2 | `forge build` passes | |
| 3 | Deployment scripts created | |
| 3 | Config files per chain/env | |
| 3 | npm deploy scripts added | |
| 4 | Upgrade scripts (if applicable) | |
| 5 | Workflow scripts (if applicable) | |
| 6 | `Base.t.sol` created | |
| 6 | `<Contract>Base.t.sol` per contract | |
| 6 | Tests restructured | |
| 6 | BTT `.tree` files (if adopted) | |
| 6 | Test naming conventions applied | |
| 7 | Reports directory (if applicable) | |
| 8 | Documentation (if desired) | |
| 9 | `forge build` clean | |
| 9 | `npm run test:local` passes | |

---
name: foundry-create
description: "[Solidity] Initialize a new Foundry project from forge-template. Runs forge init --template, customizes chains/environments, upgradeability, and optionally strips example contracts."
argument-hint: "<project-name>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Solidity — Create New Foundry Project

Initialize a new Foundry project from the forge-template and customize it based on user preferences.

**Input**: `$ARGUMENTS` — the project name (e.g. `my-defi-protocol`, `vault-contracts`)

---

## Phase 0: Parse & Prerequisites

1. Extract `PROJECT_NAME` from `$ARGUMENTS` (required — if empty, ask the user)
2. Verify prerequisites:
   ```bash
   forge --version
   node --version
   ```
3. Check the current directory — it may already have `.claude/` and `docs/` (pre-installed from the skills repo). This is fine — `--force` will handle it.

---

## Phase 1: Questions

**Ask ALL questions before touching anything.**

### 1. Upgradeability

> "Should contracts be upgradeable or non-upgradeable?"

- **Upgradeable (default)**: UUPS proxies via `UUPSOwnable2Step`, OZ upgradeable imports, `initialize()` pattern, `Deployer` with `_createProxy()`
- **Non-upgradeable**: Simple `Ownable`, constructors, direct deploys via CREATE2, no proxies

### 2. Chains and environments

> "What chains and environments do you need? Examples: Sepolia DEV/INT/STA + Polygon PRO, only Sepolia DEV, etc."

Collect the list of `(chain, environment)` pairs. Valid environments: `DEV`, `INT`, `STA`, `PRO`.

### 3. Keep example contracts?

> "The template includes a Counter example contract. Do you want to keep it as a reference, or strip it for a clean slate?"

### 4. Author name

> "What name should appear in `@author` NatSpec tags? (default: keep `gperezalba`)"

### 5. Solidity version

> "What Solidity version? (default: `0.8.24`)"

### Confirm

Summarize all answers and ask for confirmation before proceeding.

---

## Phase 2: Initialize

```bash
forge init --template https://github.com/gperezalba/forge-template . --force
```

### Post-init checks

1. Verify submodules exist:
   - `lib/forge-std`
   - `lib/openzeppelin-contracts`
   - `lib/openzeppelin-contracts-upgradeable` (only if upgradeable)
2. If any are missing: `forge install` the corresponding repo
3. If `.claude/` was created by the template, **delete it** — the user's pre-installed `.claude/` takes precedence. Check if `.claude/` existed before `forge init` and restore/preserve it.

---

## Phase 3: Non-upgradeable path

**Skip this phase if the user chose upgradeable.**

When the user chose non-upgradeable, rewrite the entire infrastructure to remove proxy patterns.

### 3.1 Remove upgradeable dependencies

```bash
# Remove the submodule
git rm lib/openzeppelin-contracts-upgradeable
```

Remove from `.gitmodules` the entry for `openzeppelin-contracts-upgradeable`.

Remove from `remappings.txt` the line:
```
@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/
```

### 3.2 Delete proxy utilities

Delete `src/utils/proxy/UUPSOwnable2Step.sol` (and `src/utils/proxy/` directory if empty).

### 3.3 Rewrite `src/utils/Deployer.sol`

Transform from proxy-based to direct deployment:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

/// @title Deployer
/// @author <AUTHOR>
/// @notice Deploys and initializes project contracts in a single transaction
contract Deployer {
    /// @notice Addresses of the deployed contracts
    struct Addresses {
        // Empty — add contract addresses here
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

    /// @notice Deploys and initializes all project contracts
    /// @param config Deployment configuration (owner, etc.)
    function deploy(Addresses calldata, Config calldata config) external {
        // solhint-disable-next-line avoid-tx-origin
        if (tx.origin != AUTHORIZED) revert Deployer_Unauthorized();
        if (_deployed) revert Deployer_AlreadyDeployed();
        _deployed = true;

        // Deploy contracts here

        emit Deploy();
    }
}
```

**Key differences from upgradeable version:**
- No `ERC1967Proxy` import
- No `_createProxy()` helper
- `deploy()` receives `Addresses calldata` (for future contract addresses) and `Config calldata config`
- `Addresses` struct is empty (contracts will be added with `/sol-add-contract`)
- No interface imports

### 3.4 Rewrite `script/deployment/misc/DeployContracts.sol`

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity <SOLIDITY_VERSION>;

// solhint-disable

import {Deployer} from "src/utils/Deployer.sol";
import {Create2Utils} from "script/utils/Create2Utils.sol";

contract DeployContracts {
    struct Report {
        Deployer.Config deployerConfig;
        Deployer.Addresses contracts;
        address deployer;
    }

    function _deployContracts(Deployer.Config memory deployerConfig, string memory envLabel, string memory version)
        internal
        returns (Report memory deployReport)
    {
        Create2Utils.loadCreate2Factory();
        Deployer.Addresses memory contracts = _deployContractImplementations(version);
        Deployer deployer = _deployDeployer(contracts, deployerConfig, envLabel, version);
        deployReport.deployerConfig = deployerConfig;
        deployReport.contracts = contracts;
        deployReport.deployer = address(deployer);
        return deployReport;
    }

    function _deployContractImplementations(string memory version)
        internal
        returns (Deployer.Addresses memory contracts)
    {
        // Deploy contracts via CREATE2 here
        return contracts;
    }

    function _deployDeployer(
        Deployer.Addresses memory contracts,
        Deployer.Config memory deployerConfig,
        string memory envLabel,
        string memory version
    ) internal returns (Deployer deployer) {
        bytes32 salt = Create2Utils.computeSalt("Deployer", envLabel, version);
        deployer = Deployer(Create2Utils.create2Deploy(salt, type(Deployer).creationCode));
        deployer.deploy(contracts, deployerConfig);
    }
}
```

**Key differences:**
- `Report` has `contracts` instead of `implementations` + `proxies`
- `_deployContractImplementations()` replaces `_deployImplementations()`
- `_deployDeployer()` returns only the deployer (no proxies)
- No proxy reads from Deployer

### 3.5 Rewrite `script/deployment/misc/DeployReport.s.sol`

Replace the proxies and implementations blocks with a single contracts block:

In `_writeJsonDeployReport()`:
- Remove the `proxiesOutput` block entirely
- Rename the `impOutput` block to `contractsOutput` and use label `"contracts"` instead of `"implementations"`
- The contracts block is empty (no `vm.serializeAddress` calls) since no contracts are deployed yet
- Update the final serialization: `vm.serializeString(jsonReport, "contracts", contractsOutput)` instead of separate proxies + implementations

### 3.6 Rewrite `script/Workflows.s.sol`

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

**Key difference:** No contract immutables, no contract imports. `Ecosystem` only has `DEPLOYER`. Contracts read from `.contracts.<name>` instead of `.proxies.<name>`.

### 3.7 Rewrite `test/Base.t.sol`

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

    // Mock USDT for testing
    ERC20Mock public mockUsdt = new ERC20Mock("Test USDT", "TUSDT", 6);

    function setUp() public virtual {
        vm.label(address(mockUsdt), "mockUsdt");

        // Deploy contracts
        _deployProjectContracts();

        vm.label(deployReport.deployer, "deployer");
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

**Key difference:** No `implementations.*` labels (no proxy/implementation separation).

### 3.8 Rewrite example contracts (if kept)

**Discovery**: Read `Deployer.sol` → extract fields from `struct Addresses` → those are the template's example contracts.

For each discovered contract (e.g. `counter` → `Counter`):

**Contract (`src/<Name>.sol`)**:
- Replace `UUPSOwnable2Step` with `Ownable` from `@openzeppelin/contracts/access/Ownable.sol`
- Replace `initialize()` with `constructor(address owner_) Ownable(owner_)`
- Remove `__Ownable_init`, `__Ownable2Step_init`, `__UUPSUpgradeable_init`, `__UUPSOwnable2Step_init`
- Remove `initializer` modifier
- Keep all business logic unchanged

**Interface (`src/interfaces/I<Name>.sol`)**:
- Remove `initialize()` function signature
- Keep all other signatures, errors, events

**Test base (`test/<Name>Base.t.sol`)**:
- Read from `deployReport.contracts.<name>` instead of `deployReport.proxies.<name>`

**Single-deployment script (`script/single-deployments/<Name>.s.sol`)**:
- Remove `DeployCounterProxy` contract entirely (no proxies)
- Rename `DeployCounterImplementation` to `Deploy<Name>`
- Remove `ERC1967Proxy` import and interface import
- Write to `.contracts.<name>` instead of `.implementations.<name>`

**Unit tests (`test/unit/<Name>/`)**:
- Delete `initialize.tree` and `initialize.t.sol` (no `initialize()` in non-upgradeable)
- In remaining tests: no changes needed if they go through the base fixture

**`package.json`**:
- Remove `:proxy:` scripts for example contracts
- Rename `:impl:` scripts to just the contract deploy (drop `:impl` suffix)

---

## Phase 4: Strip example contracts

**Skip this phase if the user chose to keep examples.**

### Discovery (dynamic — do NOT hardcode "Counter")

1. Read `src/utils/Deployer.sol`
2. Parse the `struct Addresses` fields → each field is a camelCase contract name
3. Convert to PascalCase → those are the example contracts (e.g. `counter` → `Counter`)
4. For each contract, identify these files:
   - `src/<Name>.sol`
   - `src/interfaces/I<Name>.sol`
   - `test/<Name>Base.t.sol`
   - `test/unit/<Name>/` (entire directory)
   - `script/single-deployments/<Name>.s.sol`

Present the list to the user: "I found these example contracts: [list]. I'll remove them and leave empty scaffolding."

### Delete files

For each discovered contract:
- `src/<Name>.sol`
- `src/interfaces/I<Name>.sol`
- `test/<Name>Base.t.sol`
- `test/unit/<Name>/` (entire directory, including `.tree` and `.t.sol` files)
- `script/single-deployments/<Name>.s.sol`

### Edit scaffolding to be empty

**`src/utils/Deployer.sol`** — If upgradeable:
- `Addresses {}` empty struct
- `Config` keeps only `owner`
- `deploy()` body: only the auth checks, `_deployed = true`, and `emit Deploy()` — no proxy creation
- `Deploy` event: no parameters
- Remove interface imports for deleted contracts

**`src/utils/Deployer.sol`** — If non-upgradeable (already rewritten in Phase 3):
- Should already be empty from Phase 3.3

**`script/deployment/misc/DeployContracts.sol`** — If upgradeable:
- `_deployImplementations()`: empty body, just `return implementations;`
- `_deployDeployer()`: keep deployer deploy + `deployer.deploy()` call, but no `proxies.<name> = ...` reads
- Remove contract imports for deleted contracts

**`script/deployment/misc/DeployContracts.sol`** — If non-upgradeable:
- `_deployContractImplementations()`: empty body, just `return contracts;`
- Remove contract imports

**`script/deployment/misc/DeployReport.s.sol`**:
- Proxies block (if upgradeable): empty — `proxiesOutput = vm.serializeString(jsonProxies, "empty", "");` or use a dummy to get valid JSON
- Implementations block (if upgradeable): empty — same pattern
- Contracts block (if non-upgradeable): empty — same pattern

**Actually**: For empty serialization blocks, use this pattern to produce valid JSON:
```solidity
{
    string memory jsonProxies = "proxies";
    proxiesOutput = vm.serializeString(jsonProxies, "_", "");
}
```

**`script/Workflows.s.sol`**:
- Remove contract imports
- Remove contract immutables from `Ecosystem`
- Remove workflow contracts (e.g. `CounterSetNumber`)
- Keep only `Ecosystem` with `DEPLOYER`

**`test/Base.t.sol`**:
- Remove `vm.label` lines for deleted contract implementations/proxies
- Keep the deployment infrastructure

**`package.json`**:
- Remove all npm scripts that reference deleted contracts (search by camelCase name in script keys)
- Keep deploy scripts for chains/environments, test scripts, build, lint, etc.

---

## Phase 5: Customize configs

### 5.1 `package.json`

- Set `"name"` to `PROJECT_NAME`
- Set `"version"` to `"1.0.0"`
- **Deploy scripts**: Keep only scripts for chosen chain/env combinations. Remove the rest.
  - Pattern: `deploy:<chain>:<env>` → keep if `(chain, env)` was chosen
  - Pattern: `deploy:<contract>:impl:<chain>` / `deploy:<contract>:proxy:<chain>` → keep only for chosen chains
  - Pattern: `<contract>:<action>:<chain>` → keep only for chosen chains
- Update `"repository"` and `"homepage"` — clear the URLs or set to empty strings

### 5.2 `foundry.toml`

- Update `solc_version` if user chose a different Solidity version
- **`[rpc_endpoints]`**: Keep only entries for chosen chains. Remove the rest.
- **`[etherscan]`**: Keep only entries for chosen chains. Remove the rest.

### 5.3 `.env.example`

- Keep only `RPC_*` variables for chosen chains
- Keep `PRIVATE_KEY` and `ETHERSCAN_API_KEY` always

### 5.4 `.solhint.json`

- If the Solidity version changed: update `compiler-version` rule to match (e.g. `">0.8.0"` → appropriate range)

### 5.5 Config files (`script/deployment/config/`)

Map chain/env pairs to config files:

| Chain + Env | Config file | Deploy entry point |
|-------------|------------|-------------------|
| Sepolia DEV | `ConfigSepoliaDEV.sol` | `DeploySepoliaDEV.s.sol` |
| Sepolia INT | `ConfigSepoliaINT.sol` | `DeploySepoliaINT.s.sol` |
| Sepolia STA | `ConfigSepoliaSTA.sol` | `DeploySepoliaSTA.s.sol` |
| Polygon PRO | `ConfigPolygon.sol` | `DeployPolygon.s.sol` |

- **Delete** config files and deploy entry points for chain/env combinations NOT chosen
- **Keep** the ones that match chosen combinations
- In kept config files: replace hardcoded addresses with `address(1)` placeholders (owner, tokens, etc.)
- If a user-chosen combination doesn't have a template file (e.g. Arbitrum, Base), **create** new config + deploy entry files using the same structure as the kept ones (see sol-scaffold skill for canonical templates)

### 5.6 Solidity version update

If the user chose a different Solidity version than `0.8.24`:

```bash
# Update pragma in ALL .sol files
```

Use Grep to find all `.sol` files with `pragma solidity 0.8.24` and Edit each one to the new version.

---

## Phase 6: Author tags

If the user provided an author name different from `gperezalba`:

- Find all `@author gperezalba` in `src/**/*.sol` and replace with `@author <NEW_AUTHOR>`
- Also update `package.json` `"author"` field

---

## Phase 7: CLAUDE.md

Update `CLAUDE.md` at the project root:

- Replace `forge-template` with `PROJECT_NAME` in the title and description
- If **non-upgradeable**: Update the Architecture section:
  - Remove references to UUPS proxy pattern, `UUPSOwnable2Step`
  - Change "Owner = restrictive multisig (upgrades only)" to "Owner = multisig (admin operations)"
  - Remove proxy-related workflow descriptions
- Verify all `docs/` references in the References section still point to existing files. Remove broken links.

---

## Phase 8: Git commit

```bash
git add .
git commit -m "chore: initialize <PROJECT_NAME> from forge-template"
```

Replace `<PROJECT_NAME>` with the actual project name.

---

## Phase 9: Validation

```bash
forge build
npm run test:local
```

- If **build fails**: diagnose and fix. Common issues:
  - Missing imports after removing upgradeable dependencies
  - Struct field mismatches after rewriting DeployContracts
  - Pragma version mismatches
- If **tests fail**: diagnose and fix. Common issues:
  - Test referencing `deployReport.proxies.*` when it should be `deployReport.contracts.*`
  - Missing contract that was stripped
  - Initialize tests still present when non-upgradeable

After all passes, report the result and list next steps:

> **Project initialized successfully!**
>
> Next steps:
> 1. Add your first contract: `/sol-add-contract <ContractName>`
> 2. Configure real addresses in `script/deployment/config/Config*.sol`
> 3. Copy `.env.example` to `.env` and fill in your keys
> 4. Review `CLAUDE.md` for project conventions

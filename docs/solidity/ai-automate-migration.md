# AI-Automated Migration Guide

Step-by-step process for migrating an existing Foundry project to this template's structure. Designed to be followed interactively — each phase asks questions before making changes.

**Golden rule**: Never modify contract logic in `src/` unless explicitly requested. This guide restructures infrastructure (scripts, tests, config, directory layout), not business logic.

---

## Pre-Migration: Discovery

Before starting, gather information about the existing project:

### Questions to ask

1. **What is the project's root path?**
2. **What Solidity version does the project use?** (check `foundry.toml` or pragma statements)
3. **List all production contracts** in `src/` — names, whether they're upgradeable, and their proxy pattern (if any)
4. **List all existing scripts** — what do they do? (deploy, upgrade, operational actions)
5. **List all existing tests** — unit, fuzz, integration, fork? What structure?
6. **What dependencies are installed?** (`lib/` submodules or `package.json`)
7. **Is there a deployment report or address registry?** How are deployed addresses tracked?
8. **Are there multiple chains/environments?** Which ones?
9. **Is there a `.env` file?** What variables does it contain?

### Read these files (if they exist)

- `foundry.toml` — compiler settings, remappings, rpc endpoints
- `package.json` — npm scripts, dependencies
- `remappings.txt` — import path mappings
- `.solhint.json` — linting rules
- Any existing `README.md` or docs

---

## Phase 1: Project Configuration

### 1.1 `foundry.toml`

**Ask**: Should the existing `foundry.toml` be replaced with the template's version or merged?

Ensure these settings are present (merge or replace):

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

**Ask**: Does the project already have a `package.json`? Should we create one or extend the existing one?

Ensure npm scripts exist for:
- `build`, `test`, `test:local`, `test:fork`, `coverage`, `solhint:check`, `solhint:fix`, `doc`
- Deploy scripts per chain/env (added in Phase 3)
- Workflow scripts per action (added in Phase 5)

### 1.3 `.solhint.json`

**Ask**: Does the project have solhint configured? Should we adopt the template's rules?

Template rules enforce:
- `private-vars-leading-underscore: error`
- `func-param-name-mixedcase: error`
- `modifier-name-mixedcase: error`
- `use-forbidden-name: error`
- Double quotes for strings

### 1.4 `remappings.txt`

Update import remappings to match the template's style:

```
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/
```

### 1.5 Dependencies

**Ask**: What dependencies does the project use? Which ones need to be added?

Required:
- `openzeppelin-contracts` (if not present)
- `openzeppelin-contracts-upgradeable` (if using upgradeable contracts)

Optional:
- `solady` (gas-optimized alternatives)

---

## Phase 2: Source Structure (`src/`)

**Reminder**: Do NOT modify contract logic. Only restructure files and adjust imports if needed.

### Questions to ask

1. **Are contracts upgradeable?** If yes, what proxy pattern? (UUPS, Transparent, Beacon)
   - If UUPS → align with template (good, minimal changes)
   - If Transparent → **ask** if the user wants to migrate to UUPS
   - If not upgradeable → **ask** if the user wants to add upgradeability
   - If the user wants to keep the current pattern → skip UUPSOwnable2Step, adapt scripts accordingly

2. **Does the project have interfaces?** If not, **ask** if we should extract them
3. **Is there a factory/deployer contract?** Or does each script deploy independently?

### Actions (based on answers)

#### If adopting UUPS pattern

- Copy `src/utils/proxy/UUPSOwnable2Step.sol` from the template
- Each upgradeable contract should inherit `UUPSOwnable2Step` (or equivalent)
- Ensure `initialize()` exists with `initializer` modifier
- Ensure `_authorizeUpgrade()` is `onlyOwner`

#### Directory restructuring

Move files to match:

```
src/
├── ContractA.sol
├── ContractB.sol
├── interfaces/
│   ├── IContractA.sol
│   └── IContractB.sol
└── utils/
    ├── Deployer.sol              ← created in Phase 3 (if chosen)
    └── proxy/
        └── UUPSOwnable2Step.sol  ← if adopting UUPS
```

**Ask**: Should interfaces be extracted from contracts into `src/interfaces/`? (Define errors, events, and external function signatures in the interface)

#### Import path updates

After moving files, update all import paths. Run `forge build` to verify nothing breaks.

---

## Phase 3: Deployment Scripts

This is the biggest decision point. The template supports three deployment styles.

### Questions to ask

1. **Which deployment style do you want?**

   | Style | Description | When to use |
   |-------|-------------|-------------|
   | **Full Deployer** | Atomic factory deploys all contracts in one tx | New projects, clean deployments, deterministic addresses needed |
   | **Single scripts** | One script per contract, independent deploys | Projects that add contracts incrementally |
   | **Keep original** | Don't change the existing deployment scripts | Already working, no benefit from migration |

2. **Do you want CREATE2 deterministic addresses?**
   - Yes → need `Create2Utils.sol` and SafeSingletonFactory
   - No → standard `new` deployments

3. **What chains and environments does the project target?**
   - Each combination needs a config file: `Config<Chain><Env>.sol`
   - Environments: DEV, INT, STA (testnets), PRO (mainnet)

4. **Do you want a deployment report system?** (JSON file tracking all deployed addresses)
   - Yes → need `DeployReport.s.sol` + `reports/` directory
   - No → addresses managed manually or via existing system

### If choosing Full Deployer

Create the full deployment infrastructure:

```
script/
├── deployment/
│   ├── Deploy<Chain><Env>.s.sol       ← one per chain/env
│   ├── config/
│   │   ├── ConfigAbstract.sol
│   │   └── Config<Chain><Env>.sol     ← one per chain/env
│   └── misc/
│       ├── DeployBase.s.sol
│       ├── DeployContracts.sol
│       └── DeployReport.s.sol
└── utils/
    └── Create2Utils.sol               ← if using CREATE2
```

For each contract in the project:
1. Add its address to `Deployer.Addresses` struct
2. Add its config to `Deployer.Config` struct (init params beyond owner)
3. Add `_createProxy()` call in `Deployer.deploy()`
4. Add CREATE2 deploy in `DeployContracts._deployImplementations()`
5. Add serialization in `DeployReport._writeJsonDeployReport()`

Also create `src/utils/Deployer.sol`:
- Constructor: set authorized deployer
- `deploy()`: create proxies, initialize, guard against re-execution
- One `_createProxy()` call per contract

### If choosing Single scripts only

```
script/
├── single-deployments/
│   ├── SingleDeployBase.s.sol
│   └── <ContractName>.s.sol        ← one per contract
└── utils/
    └── Create2Utils.sol            ← if using CREATE2
```

Each contract gets two script contracts:
- `Deploy<Contract>Implementation` — impl only
- `Deploy<Contract>Proxy` — impl + proxy

### If keeping original

- Leave `script/` as-is
- Only add upgrade and workflow scripts if desired (Phases 4 and 5)

### npm scripts for deployment

Add to `package.json`:

```json
{
  "scripts": {
    "deploy:sepolia:dev": "source .env && forge script script/deployment/DeploySepoliaDEV.s.sol:DeploySepoliaDEV --ffi --rpc-url sepolia --private-key ${PRIVATE_KEY} --broadcast --slow -vvvv --verify --chain sepolia"
  }
}
```

---

## Phase 4: Upgrade Scripts

### Questions to ask

1. **Are any contracts upgradeable?** If not, skip this phase entirely
2. **Has the project been deployed already?** If yes, do we need to migrate existing proxies?
3. **Do you want storage layout checks before upgrading?**

### If upgrades are needed

```
script/
└── upgrades/
    ├── Upgrade<ContractName>.s.sol
    └── storage-check/
        └── <ContractName>.s.sol
```

Each upgrade script:
1. Reads current proxy from deployment report
2. Deploys new implementation
3. Calls `proxy.upgradeToAndCall(newImpl, "")`
4. Updates the report

---

## Phase 5: Workflow Scripts

### Questions to ask

1. **Are there operational/admin functions that need to be called post-deployment?** (pause, setConfig, grantRole, etc.)
2. **Should we create workflow scripts for testnet admin actions?**
3. **What admin functions exist across all contracts?**

### If workflows are needed

Create `script/Workflows.s.sol` with:
- `Ecosystem` base: reads all deployed addresses from report
- One contract per action: `<Contract><Action>` inheriting `Ecosystem`

Add npm scripts:

```json
{
  "scripts": {
    "counter:setNumber:sepolia:dev": "source .env && export ENV=DEV && forge script script/Workflows.s.sol:CounterSetNumber --rpc-url sepolia --private-key ${PRIVATE_KEY} --broadcast --slow -vvvv"
  }
}
```

---

## Phase 6: Test Structure

### Questions to ask

1. **What test structure does the project currently have?**
   - Flat (all tests in `test/`)?
   - By contract (test/ContractA/, test/ContractB/)?
   - By type (test/unit/, test/integration/)?
   - Other?

2. **Do you want to adopt BTT (Branching Tree Technique)?**
   - Yes → write `.tree` specs, scaffold with bulloak, implement
   - No → restructure tests into the directory layout but keep free-form style

3. **Do the tests already have a shared fixture/base?** Or does each test deploy its own contracts?

4. **Should we create `.tree` files for existing test coverage or start fresh?**
   - Reverse-engineer: analyze existing tests and write `.tree` files that match current coverage
   - Start fresh: write `.tree` files from scratch based on contract functions
   - Hybrid: keep existing tests as-is, write `.tree` files only for new functions

5. **Does the project have fork tests?** Do they follow the `testFork` naming convention?

6. **Does the project have fuzz tests?** Invariant tests?

### Test hierarchy to create

```
test/
├── Base.t.sol                     ← root fixture
├── <ContractName>Base.t.sol       ← per-contract fixture
├── unit/<ContractName>/           ← BTT unit tests
├── integration/                   ← cross-contract tests
├── invariant/                     ← if applicable
│   └── handlers/
├── fuzz/                          ← standalone fuzz (if not inline)
├── fork/                          ← fork tests
└── mocks/                         ← test-only mocks
```

### Step 6.1: Create `Base.t.sol`

The root fixture deploys the full ecosystem and provides shared accounts:

```solidity
contract Base is Test, DeployContracts, ConfigAbstract {
    address internal owner;
    address internal nonOwner;
    // ... shared accounts

    function setUp() public virtual {
        owner = makeAddr("owner");
        nonOwner = makeAddr("nonOwner");
        // deploy all contracts via DeployContracts
    }
}
```

**Ask**: Does the project already have a shared deployment in tests? Can we reuse `DeployContracts` from Phase 3, or do tests deploy differently?

### Step 6.2: Create `<Contract>Base.t.sol` for each contract

```solidity
contract CounterBase is Base {
    Counter internal counter;

    function setUp() public virtual override {
        super.setUp();
        counter = Counter(deployReport.proxies.counter);
        vm.label(address(counter), "Counter");
    }
}
```

### Step 6.3: Migrate or create unit tests

**If adopting BTT**:
1. For each external/public function, create `test/unit/<Contract>/functionName.tree`
2. Run `bulloak scaffold -w -s <version> <path>`
3. Implement the scaffold (see [btt-tests.md](btt-tests.md) and [test-implementation.md](test-implementation.md))
4. Port assertions and edge cases from existing tests into the new structure

**If keeping free-form**:
1. Move tests to `test/unit/<Contract>/`
2. Update inheritance to use `<Contract>Base`
3. Remove per-test contract deployments — use the fixture

### Step 6.4: Categorize remaining tests

- Cross-contract interaction tests → `test/integration/`
- Tests with `testFork` → `test/fork/`
- Fuzz tests → inline in unit tests or `test/fuzz/`
- Invariant tests → `test/invariant/` with handlers

### Step 6.5: Rename test functions

Ensure naming conventions match:

| Type | Prefix |
|------|--------|
| Standard | `test_` |
| Fuzz | `testFuzz_` |
| Fork | `testFork_` |
| Revert | `test_RevertWhen_` |
| Event | `test_EmitWhen_` |
| Invariant | `invariant_` |

### Step 6.6: Update npm test scripts

```json
{
  "scripts": {
    "test": "forge test -vvv",
    "test:local": "forge test --no-match-test testFork -vvv",
    "test:fork": "forge test --match-test testFork --fork-url $RPC_URL -vvv"
  }
}
```

---

## Phase 7: Reports Directory

### Questions to ask

1. **Do you want the deployment report system?** (If answered in Phase 3, skip)
2. **Are there existing deployed addresses that should be imported into the first report?**

### If yes

Create the directory structure:

```
reports/
└── <chainId>/
    └── <env>/
        └── latest-deployment.json
```

If the project has existing deployed addresses, create `latest-deployment.json` manually with the current state:

```json
{
  "owner": "0x...",
  "deployer": "0x...",
  "proxies": {
    "contractA": "0x...",
    "contractB": "0x..."
  },
  "implementations": {
    "contractA": "0x...",
    "contractB": "0x..."
  }
}
```

---

## Phase 8: Documentation

### Questions to ask

1. **Do you want to copy the template's `docs/solidity/` docs into the project?**
2. **Do you want a `CLAUDE.md` at the project root?**

### If yes

- Copy relevant docs from `docs/solidity/` (adapt examples to the project's contracts)
- Create `CLAUDE.md` with project-specific commands, gotchas, architecture, and references
- Create `docs/INDEX.md` referencing all docs

---

## Phase 9: Validation

After all phases are complete, run these checks:

```bash
# 1. Build compiles clean
forge build

# 2. All tests pass
npm run test:local

# 3. Linting passes
npm run solhint:check

# 4. Formatting is consistent
forge fmt --check

# 5. (If BTT) Tree-to-test sync
bulloak check test/unit/**/*.tree
```

Fix any issues before considering the migration complete.

---

## Migration Checklist

| Phase | Item | Status |
|-------|------|--------|
| 1 | `foundry.toml` updated | |
| 1 | `package.json` with npm scripts | |
| 1 | `.solhint.json` configured | |
| 1 | `remappings.txt` updated | |
| 1 | Dependencies installed | |
| 2 | `src/` restructured (interfaces, utils) | |
| 2 | Proxy pattern aligned (if applicable) | |
| 2 | `forge build` passes | |
| 3 | Deployment scripts created (chosen style) | |
| 3 | Config files per chain/env | |
| 3 | npm deploy scripts added | |
| 4 | Upgrade scripts (if applicable) | |
| 5 | Workflow scripts (if applicable) | |
| 6 | `Base.t.sol` created | |
| 6 | `<Contract>Base.t.sol` per contract | |
| 6 | Unit tests restructured | |
| 6 | `.tree` files (if BTT adopted) | |
| 6 | Fork/fuzz/invariant tests categorized | |
| 6 | Test naming conventions applied | |
| 7 | Reports directory (if applicable) | |
| 8 | Documentation (if desired) | |
| 9 | `forge build` clean | |
| 9 | `npm run test:local` passes | |
| 9 | `npm run solhint:check` passes | |
| 9 | `forge fmt --check` clean | |

---

## References

- [project-structure.md](project-structure.md) — Target directory layout
- [naming-conventions.md](naming-conventions.md) — Naming rules at every level
- [deployment-flow.md](deployment-flow.md) — Deployment script architecture
- [script-workflows.md](script-workflows.md) — Testnet workflow scripts
- [btt-tests.md](btt-tests.md) — BTT tree spec format and bulloak workflow
- [test-implementation.md](test-implementation.md) — Test types, inheritance, and patterns
- [contracts-implementation.md](contracts-implementation.md) — Smart contract best practices
- [natspec.md](natspec.md) — NatSpec documentation rules

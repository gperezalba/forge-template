# Project Directory Structure

## Root Layout

```
project/
├── src/                    # Smart contracts (production code)
├── test/                   # All tests
├── script/                 # Deployment, upgrades, and operational scripts
├── docs/solidity/          # Claude context & project documentation
├── lib/                    # Foundry dependencies (git submodules)
├── reports/                # Generated deployment reports (per chain/env)
├── foundry.toml
├── remappings.txt
├── package.json
└── .solhint.json
```

---

## `src/` — Smart Contracts

```
src/
├── ContractA.sol
├── ContractB.sol
├── interfaces/
│   ├── IContractA.sol
│   └── IContractB.sol
└── utils/
    ├── Deployer.sol            # Factory that deploys all proxies atomically
    └── proxy/
        └── UUPSOwnable2Step.sol  # Base for UUPS + Ownable2Step pattern
```

- One contract per file
- `interfaces/` mirrors the contract names with `I` prefix
- `utils/` for deployment infrastructure and shared base contracts

---

## `script/` — Scripts

```
script/
├── deployment/                 # Full project deployments (all contracts at once)
│   ├── Deploy<Chain><Env>.s.sol    # Entry point per chain/env (e.g. DeploySepoliaDEV.s.sol)
│   ├── config/
│   │   ├── ConfigAbstract.sol      # Abstract config with shared structure
│   │   └── Config<Chain><Env>.sol  # Concrete config per chain/env
│   └── misc/
│       ├── DeployBase.s.sol        # Abstract base script (run() + orchestration)
│       ├── DeployContracts.sol     # Deployment logic (implementations + proxies)
│       └── DeployReport.s.sol      # JSON report generation
│
├── single-deployments/         # Individual contract deployments (post-initial)
│   ├── SingleDeployBase.s.sol      # Base: reads report, version, env helpers
│   └── <ContractName>.s.sol        # One script per contract (impl + proxy)
│
├── upgrades/                   # Upgrade scripts
│   ├── Upgrade<ContractName>.s.sol     # Deploys new impl + calls upgradeTo
│   └── storage-check/
│       └── <ContractName>.s.sol        # Storage layout validation pre-upgrade
│
├── Workflows.s.sol             # Operational scripts (e.g. setNumber, pause)
│                               #   Loads ecosystem from deployment report
└── utils/
    └── Create2Utils.sol        # CREATE2 factory helpers
```

### Deployment flow

```
Deploy<Chain><Env>.s.sol        →  inherits DeployBase + Config<Chain><Env>
    ↓
DeployBase.s.sol                →  run(): loads config, broadcasts, calls _deployContracts()
    ↓
DeployContracts.sol             →  _deployContracts(): deploys impls + Deployer + proxies
    ↓
DeployReport.s.sol              →  writes JSON report to reports/<chainId>/<env>/
```

### Single deployments flow

```
SingleDeployBase.s.sol          →  reads existing report, provides version/env helpers
    ↓
<ContractName>.s.sol            →  deploys one impl + proxy, updates the report
```

### Upgrades flow

```
storage-check/<ContractName>.s.sol   →  validates storage layout compatibility
    ↓
Upgrade<ContractName>.s.sol          →  deploys new impl + calls upgradeToAndCall
```

### Workflows flow

```
Workflows.s.sol                 →  Ecosystem constructor reads deployed addresses from report
                                   Each function is an operational action (setNumber, etc.)
```

---

## `test/` — Tests

```
test/
├── Base.t.sol                  # Root test fixture: deploys full ecosystem, defines accounts
├── <ContractName>Base.t.sol    # Per-contract fixture: inherits Base, exposes contract instance
│
├── unit/                       # Unit tests (one function, isolated)
│   └── <ContractName>/
│       ├── functionName.tree       # BTT spec (see btt-tests.md)
│       ├── functionName.t.sol      # BTT test implementation
│       └── ...
│
├── integration/                # Integration tests (cross-contract interactions)
│   └── <TestName>.t.sol
│
├── invariant/                  # Invariant/stateful fuzz tests
│   ├── handlers/
│   │   └── <ContractName>Handler.sol   # Actors that call contract functions
│   └── <ContractName>.invariant.t.sol  # Invariant definitions
│
├── fuzz/                       # Standalone fuzz tests (when not inline in unit tests)
│   └── <ContractName>/
│       └── functionName.t.sol
│
├── fork/                       # Fork tests (run against live network state)
│   └── <TestName>.t.sol
│
└── mocks/                      # Test-only mock contracts
    └── ERC20Mock.sol
```

### Test hierarchy

```
Base.t.sol                      →  DeployContracts + ConfigAbstract
                                   Deploys full ecosystem, creates owner/nonOwner accounts
    ↓
<ContractName>Base.t.sol        →  inherits Base.t.sol
                                   Exposes the specific contract instance + labels
    ↓
unit/<ContractName>/X.t.sol     →  inherits <ContractName>Base.t.sol
                                   Tests one function following BTT structure
```

For all naming conventions (files, contracts, functions, variables, etc.) see [naming-conventions.md](naming-conventions.md).

---

## `reports/` — Deployment Reports

```
reports/
└── <chainId>/
    └── <env>/
        └── latest-deployment.json    # Addresses of all deployed contracts
```

Generated automatically by `DeployReport.s.sol`. Read by `Workflows.s.sol`, `SingleDeployBase.s.sol`, and tests.

# Deployment Flow

## Overview

There are four types of scripts, each for a different stage of the project lifecycle:

| Type | When | What it does |
|------|------|-------------|
| **Full deployment** | First deploy of the project on a chain/env | Deploys all implementations + Deployer + all proxies atomically |
| **Single deployment** | Adding or replacing one contract post-initial deploy | Deploys one implementation (+ optionally its proxy), updates the report |
| **Upgrade** | Updating contract logic behind an existing proxy | Deploys new implementation, calls `upgradeToAndCall` on the proxy |
| **Workflow** | Operational actions on deployed contracts | Reads deployed addresses from report, calls contract functions |

All scripts produce or consume a **deployment report** at `reports/<chainId>/<env>/latest-deployment.json`.

---

## 1. Full Deployment

Deploys the entire project from scratch on a given chain + environment.

### Inheritance chain

```
Deploy<Chain><Env>.s.sol
    inherits DeployBase       (run() orchestration)
    inherits Config<Chain><Env>  (addresses, env enum, config structs)

DeployBase
    inherits ConfigAbstract   (abstract config interface)
    inherits Script           (Foundry base)
    inherits DeployReport     (JSON report generation)
    inherits DeployContracts  (deployment logic)
```

The entry point contract (`DeploySepoliaDEV`, `DeployPolygon`, etc.) is an **empty contract** — it only mixes in the base + config. All logic lives in the parents.

### Execution flow

```
run()
 │
 ├── 1. _getInitialConfig()          ← from Config<Chain><Env>
 │      returns Config { env, deployerConfig { owner } }
 │
 ├── 2. _checkInitialConfig()        ← validates owner != address(0)
 │
 ├── 3. Read version from package.json
 │
 ├── 4. vm.startBroadcast()
 │   │
 │   └── _deployContracts(deployerConfig, envLabel, version)
 │       │
 │       ├── a. Create2Utils.loadCreate2Factory()
 │       │      etches SafeSingletonFactory if not present (local/fork only)
 │       │
 │       ├── b. _deployImplementations(version)
 │       │      for each contract:
 │       │        salt = keccak256(contractName, version)
 │       │        impl = CREATE2 deploy with SafeSingletonFactory
 │       │      returns Addresses { counter: implAddress }
 │       │
 │       └── c. _deployDeployer(implementations, deployerConfig, envLabel, version)
 │              salt = keccak256("Deployer", envLabel, version)
 │              deployer = CREATE2 deploy Deployer contract
 │              deployer.deploy(implementations, config)
 │                → creates ERC1967Proxy for each contract
 │                → initializes each proxy with config.owner
 │                → sets _deployed = true (one-shot guard)
 │              returns Addresses { counter: proxyAddress }
 │
 ├── 5. vm.stopBroadcast()
 │
 ├── 6. _getEnvConfig()              ← external addresses (tokens, etc.)
 │
 └── 7. _writeJsonDeployReport()     ← writes JSON report
        → reports/<chainId>/<env>/<timestamp>-deployment.json
        → reports/<chainId>/<env>/latest-deployment.json
```

### Report structure

```json
{
  "owner": "0x...",
  "deployer": "0x...",
  "github": {
    "repository-commit": "abc123",
    "repository-branch": "master"
  },
  "proxies": {
    "counter": "0x..."
  },
  "implementations": {
    "counter": "0x..."
  },
  "tokens": {
    "usdt": "0x..."
  }
}
```

The report is written **twice**: one with a timestamp for history, and one as `latest-deployment.json` that all other scripts read from.

### Configuration system

`ConfigAbstract` defines the interface:

```solidity
abstract contract ConfigAbstract {
    enum Environment { DEV, INT, STA, PRO }

    struct Config {
        Environment env;
        Deployer.Config deployerConfig;  // { owner }
    }

    struct EnvConfig {
        address usdt;                    // external token addresses, etc.
    }

    function _getInitialConfig() internal virtual returns (Config memory);
    function _getEnvConfig() internal view virtual returns (EnvConfig memory);
}
```

Each `Config<Chain><Env>` implements it with hardcoded constants:

```solidity
contract ConfigSepoliaDEV is ConfigAbstract {
    Environment internal constant _ENV = Environment.DEV;
    address internal constant _OWNER = 0x...;
    address internal constant _USDT = 0x...;
    // implements _getInitialConfig() and _getEnvConfig()
}
```

### CREATE2 determinism

All deployments use the **SafeSingletonFactory** (`0x914d...`) for CREATE2:

- **Implementations**: `salt = keccak256(contractName, version)` — same impl address across all chains for a given version
- **Deployer**: `salt = keccak256("Deployer", envLabel, version)` — different per environment (DEV vs PRO share different labels, INT is separate)
- **Proxies**: Deployed by the Deployer contract via `new ERC1967Proxy(...)` — deterministic per Deployer address
- **Idempotent**: If the address already has code, `create2Deploy` skips deployment and returns the existing address

### npm commands

```bash
npm run deploy:sepolia:dev      # DeploySepoliaDEV → sepolia, ENV=DEV
npm run deploy:sepolia:int      # DeploySepoliaINT → sepolia, ENV=INT
npm run deploy:sepolia:sta      # DeploySepoliaSTA → sepolia, ENV=STA
npm run deploy:polygon          # DeployPolygon    → polygon, ENV=PRO
```

### Adding a new chain/env

1. Create `config/Config<Chain><Env>.sol` — implement `_getInitialConfig()` and `_getEnvConfig()` with the new addresses
2. Create `Deploy<Chain><Env>.s.sol` — empty contract inheriting `DeployBase` + `Config<Chain><Env>`
3. Add the npm script in `package.json` with the right `--rpc-url`, `--chain`, and `ENV`

### Adding a new contract to the full deployment

1. Add the address field to `Deployer.Addresses` struct
2. Add the config field to `Deployer.Config` struct (if the contract needs init params beyond owner)
3. In `Deployer.deploy()`: encode initializeCalldata and call `_createProxy()`
4. In `DeployContracts._deployImplementations()`: add CREATE2 deploy for the new implementation
5. In `DeployReport._writeJsonDeployReport()`: serialize the new addresses in proxies and implementations sections
6. Update `Config<Chain><Env>` files if new config values are needed

---

## 2. Single Deployment

Deploys one contract independently, after the initial full deployment has happened. Useful for adding a new contract to an existing ecosystem or redeploying a single component.

### Base contract

`SingleDeployBase` provides helpers that read from the existing report:

```solidity
abstract contract SingleDeployBase is Script {
    function _getVersion() → reads package.json
    function _getEnv() → reads ENV env var
    function _getReportPath(env) → "reports/<chainId>/<env>/latest-deployment.json"
    function _readAddressFromReport(path, key) → reads a JSON key
    function _writeAddressToReport(path, key, addr) → updates a JSON key in-place
}
```

### Two variants per contract

Each contract typically has two script contracts in the same file:

**`Deploy<Contract>Implementation`** — Deploys only the implementation (for upgrades or pre-staging):
```
run()
 ├── Read version + env
 ├── CREATE2 deploy implementation
 └── Update report: .implementations.<contract>
```

**`Deploy<Contract>Proxy`** — Deploys implementation + a new proxy:
```
run()
 ├── Read version + env + owner from report
 ├── CREATE2 deploy implementation
 ├── Deploy ERC1967Proxy(implementation, initializeCalldata)
 └── Update report: .implementations.<contract> + .proxies.<contract>
```

### npm commands

```bash
# Implementation only
npm run deploy:counter:impl:sepolia:dev
npm run deploy:counter:impl:polygon

# Implementation + proxy
npm run deploy:counter:proxy:sepolia:dev
npm run deploy:counter:proxy:polygon
```

### Adding a new single deployment script

1. Create `single-deployments/<ContractName>.s.sol`
2. Add `Deploy<Contract>Implementation` contract inheriting `SingleDeployBase`
3. Add `Deploy<Contract>Proxy` contract inheriting `SingleDeployBase`
4. Add npm scripts in `package.json`

---

## 3. Upgrades

Deploys a new implementation and upgrades an existing proxy to point to it.

### Flow

```
run()
 ├── Read version + env
 ├── Read current proxy address from report
 ├── (Optional) Storage layout compatibility check
 ├── CREATE2 deploy new implementation
 ├── proxy.upgradeToAndCall(newImpl, "")    ← or with migration calldata
 └── Update report: .implementations.<contract>
```

### Storage check

Before upgrading, validate that the new implementation's storage layout is compatible with the old one:

```bash
# Compare local vs deployed storage layout using etherscan source
npm run diff-storage-etherscan:contract
```

This script:
1. Downloads the verified source from Etherscan
2. Runs `forge inspect` on both old and new contracts
3. Diffs the storage layouts word-by-word

### Script location

```
script/upgrades/
├── Upgrade<ContractName>.s.sol
└── storage-check/
    └── <ContractName>.s.sol
```

---

## 4. Workflows

See [script-workflows.md](script-workflows.md).

---

## Environment Variables

All scripts depend on:

| Variable | Source | Used by |
|----------|--------|---------|
| `PRIVATE_KEY` | `.env` | All scripts (signer) |
| `ENV` | Set per npm script (`DEV`, `INT`, `STA`, `PRO`) | SingleDeployBase, Workflows |
| `RPC_SEPOLIA` | `.env` → `foundry.toml` rpc_endpoints | Chain connection |
| `RPC_POLYGON` | `.env` → `foundry.toml` rpc_endpoints | Chain connection |
| `ETHERSCAN_API_KEY` | `.env` → `foundry.toml` etherscan | Contract verification |

### Common forge script flags

```bash
forge script <path>:<contract> \
    --ffi               # required for DeployReport (git commit, timestamp) \
    --rpc-url <alias>   # chain connection \
    --private-key $KEY  # signer \
    --broadcast         # actually send transactions (omit for dry-run) \
    --slow              # wait for each tx confirmation \
    -vvvv               # max verbosity \
    --verify            # verify on etherscan after deploy \
    --chain <name>      # chain for verification
```

Omit `--broadcast` to do a dry-run simulation without sending transactions.

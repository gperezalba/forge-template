# Script Workflows

## Purpose

`script/Workflows.s.sol` contains operational scripts for calling admin/privileged functions on deployed contracts. These are **testnet-only** — in production all admin actions go through a multisig (e.g. Safe), not a private key.

## When to use

- Testnet environments (`DEV`, `INT`, `STA`) where the deployer private key in `.env` has owner/admin privileges
- Setting initial state, configuring parameters, testing admin flows against real deployments
- Never in production (`PRO`) — there the owner is a multisig, not an EOA

## Structure

The file contains one base contract (`Ecosystem`) and one contract per action:

```solidity
// Base: loads all deployed contract addresses from the report
contract Ecosystem is Script {
    Deployer public immutable DEPLOYER;
    Counter public immutable COUNTER;
    // ... one immutable per deployed contract

    constructor() {
        DEPLOYER = Deployer(_getAddressFromReport(".deployer"));
        COUNTER = Counter(_getAddressFromReport(".proxies.counter"));
    }
}

// One contract per action, grouped by target contract
contract CounterSetNumber is Ecosystem {
    function run() external {
        vm.startBroadcast();
        COUNTER.setNumber(100);
        vm.stopBroadcast();
    }
}
```

## Organization

Actions are grouped by the contract they target. The contract name follows the pattern `<Contract><Action>`:

```
Ecosystem                    ← base (reads report)
├── CounterSetNumber         ← Counter.setNumber(...)
├── CounterTransferOwnership ← Counter.transferOwnership(...)
├── VaultPause               ← Vault.pause()
├── VaultUnpause             ← Vault.unpause()
└── ...
```

## npm scripts

One npm script per action + environment:

```bash
npm run counter:setNumber:sepolia:dev
npm run counter:setNumber:sepolia:int
npm run counter:setNumber:sepolia:sta
```

Pattern: `<contract>:<action>:<chain>:<env>`

Each resolves to:

```bash
source .env && export ENV=<env> && \
forge script script/Workflows.s.sol:<ContractAction> \
    --rpc-url <chain> --private-key ${PRIVATE_KEY} --broadcast --slow -vvvv
```

## Adding a new workflow

1. Add a new contract in `Workflows.s.sol` inheriting `Ecosystem`
2. Implement `run()` with `vm.startBroadcast()` / `vm.stopBroadcast()`
3. Add npm scripts in `package.json` for each testnet environment

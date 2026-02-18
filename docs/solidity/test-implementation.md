# Test Implementation

## Test Types

| Type | Location | When to use | Inherits from |
|------|----------|-------------|---------------|
| **Unit** | `test/unit/<Contract>/` | Test one function in isolation | `<Contract>Base` |
| **Fuzz** | Inline in unit tests or `test/fuzz/` | Discover edge cases with random inputs | `<Contract>Base` |
| **Integration** | `test/integration/` | Test cross-contract interactions | `Base` or `<Contract>Base` |
| **Fork** | `test/fork/` or `test/integration/` | Verify behavior against live chain state | `Test` (minimal fixture) |
| **Invariant** | `test/invariant/` | Prove properties hold across random sequences of actions | `Test` + handlers |

---

## Inheritance & Fixture Hierarchy

```
Base.t.sol                        ← deploys the full ecosystem (all contracts via DeployContracts)
                                     provides: owner, nonOwner, deployReport, mockUsdt
    ↓
<Contract>Base.t.sol              ← exposes the specific proxy instance + labels
                                     provides: counter (or vault, token, etc.)
    ↓
unit/<Contract>/function.t.sol    ← one file per function, follows BTT scaffold
```

### Rules

- **Always inherit from the deepest Base available** for the contract under test. Unit tests for Counter inherit `CounterBase`, not `Base`.
- **Use the fixture's deployed contracts** for all tests. The ecosystem is deployed once per test via `setUp()`.
- **Exception: `initialize` and constructor tests** — these need a fresh deployment, not the fixture. Deploy a new implementation + uninitialized proxy inside the test.
- **Reusable helpers go in the Base**. If a util function is used across multiple test files for the same contract, move it to `<Contract>Base`. If shared across contracts, move it to `Base`.
- **Mocks live in `test/mocks/`** and are instantiated in `Base.t.sol` so all tests can use them.

---

## Unit Tests (BTT)

Unit tests follow the BTT workflow. See [btt-tests.md](btt-tests.md) for the `.tree` specification.

### Workflow

1. Write the `.tree` file
2. Run `bulloak scaffold -w -s 0.8.24 test/unit/<Contract>/function.tree`
3. Implement the generated `.t.sol` — change as little as possible from the scaffold

### What to keep from the scaffold

- Function names and signatures — never rename them
- Modifier declarations and their attachment to functions
- `// it should ...` comments — keep them as-is, write assertions below each one

### What to add to the scaffold

- Imports (`CounterBase`, production contracts, OZ errors)
- Inheritance: `is Test, <Contract>Base`
- `setUp()` calling `super.setUp()` and assigning `testContract = contract`
- Modifier bodies (prank setup, state manipulation)
- Actual test logic: arrange, act, assert

### Template

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Test} from "forge-std/Test.sol";
import {ContractBase} from "test/ContractBase.t.sol";
import {MyContract} from "src/MyContract.sol";

contract MyContractFunctionTest is Test, ContractBase {
    MyContract internal testContract;

    function setUp() public override {
        super.setUp();
        testContract = myContract; // from ContractBase
    }

    // --- modifiers from scaffold, filled in ---

    modifier givenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    // --- test functions from scaffold, implemented ---

    function test_WhenValueIsZero() external givenTheCallerIsTheOwner {
        uint256 value = 0;

        testContract.setValue(value);

        // it should set value to zero
        assertEq(testContract.value(), value);
        // it should update the storage correctly
        assertEq(testContract.value(), 0);
    }
}
```

### Initializer tests (exception to fixture usage)

```solidity
contract MyContractInitializeTest is Test, ContractBase {
    MyContract internal implementation;
    MyContract internal testContract;

    function setUp() public override {
        super.setUp();
        implementation = new MyContract(); // fresh impl, not from fixture
    }

    modifier givenTheContractIsNotInitialized() {
        // fresh proxy, uninitialized
        testContract = MyContract(address(new ERC1967Proxy(address(implementation), "")));
        _;
    }

    modifier givenTheContractIsAlreadyInitialized() {
        // use the fixture's already-initialized proxy
        testContract = myContract;
        _;
    }
}
```

### Reverts

Use specific custom errors with `abi.encodeWithSelector`:

```solidity
// Custom error without params
vm.expectRevert(abi.encodeWithSelector(IMyContract.MyContract_ZeroAddress.selector));

// Custom error with params
vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));

// Arithmetic overflow (no specific error)
vm.expectRevert();
```

### Events

Declare the event in the test contract, then use `vm.expectEmit`:

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

function test_EmitWhen_OwnerChanged() external {
    vm.expectEmit(true, true, false, false);
    emit OwnershipTransferred(address(0), owner);
    testContract.initialize(owner);
}
```

---

## Fuzz Tests

Use fuzz testing to validate behavior across a wide range of inputs without listing every value manually.

### When to use

- The function accepts numeric ranges or arbitrary addresses
- You want to prove a property holds for **all** valid inputs, not just a few examples
- Complement to (not replacement for) BTT unit tests that cover specific branches

### Inline in unit test files

When a fuzz test is closely related to a BTT function, add it in the same file:

```solidity
function testFuzz_SetNumber(uint256 newNumber) external givenTheCallerIsTheOwner {
    testContract.setNumber(newNumber);
    assertEq(testContract.number(), newNumber);
}

function testFuzz_RevertWhen_CallerIsNotOwner(address caller, uint256 newNumber) external {
    vm.assume(caller != owner);
    vm.prank(caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    testContract.setNumber(newNumber);
}
```

### Standalone fuzz files

For more complex fuzz scenarios, use `test/fuzz/<Contract>/`:

```solidity
contract CounterFuzzTest is Test, CounterBase {
    function setUp() public override { super.setUp(); }

    function testFuzz_IncrementFromAnyValue(uint256 startValue) external {
        vm.assume(startValue < type(uint256).max);
        vm.prank(owner);
        counter.setNumber(startValue);
        counter.increment();
        assertEq(counter.number(), startValue + 1);
    }
}
```

### Tips

- Use `vm.assume()` to filter invalid inputs (not too restrictive or fuzzer becomes slow)
- Use `bound()` to constrain ranges: `amount = bound(amount, 1, 1e18)`
- Default runs: 1000 (CI: 10000) — configured in `foundry.toml`

---

## Integration Tests

Test interactions between multiple deployed contracts working together.

### When to use

- Verifying a workflow that spans multiple contracts (e.g. deposit → stake → claim)
- Testing that contracts are wired correctly after deployment
- Scenarios that don't map to a single function's BTT tree

### Structure

```solidity
// test/integration/LendingWorkflow.t.sol

contract LendingWorkflowIntegrationTest is Test, Base {
    function setUp() public override {
        super.setUp();
    }

    function test_DepositAndWithdraw() external {
        // uses multiple contracts from the fixture
    }
}
```

- Inherit from `Base` (full ecosystem) or a specific `<Contract>Base` depending on what you need
- No BTT tree needed — structure tests freely
- Name the contract `<Description>IntegrationTest`

---

## Fork Tests

Run against real chain state to verify assumptions about external contracts, deployed infrastructure, or live protocol integrations.

### When to use

- Verifying that an external dependency (e.g. SafeSingletonFactory) exists on-chain
- Testing interactions with real deployed third-party contracts (Uniswap, Aave, etc.)
- Checking behavior with real token balances and state

### Naming convention

All fork test functions **must** contain `testFork` in the name. This is how they are filtered:

- `npm run test:local` → `--no-match-test testFork` (excludes them)
- `npm run test:fork` → `--match-test testFork` (only runs them)

### Structure

```solidity
// test/fork/UniswapIntegration.t.sol

contract UniswapIntegrationForkTest is Test {
    function setUp() public {
        // minimal setup — no full ecosystem deployment needed
        // the fork provides real state
    }

    function testFork_SwapExactTokens() external {
        // interact with real Uniswap contracts on the forked chain
    }
}
```

- Typically inherit from `Test` directly (not `Base`) — the fork provides the state
- If you also need the project's contracts deployed on the fork, inherit from `Base`
- Keep fork tests in `test/fork/` or `test/integration/` depending on whether they test your contracts or external ones

### Running

```bash
# Fork tests only (uses RPC from foundry.toml)
npm run test:fork

# All tests on fork (local + fork)
npm run test:fork:all
```

---

## Invariant Tests

Prove that certain properties always hold regardless of the sequence of actions performed on the contracts.

### When to use

- Critical system properties: "total supply never exceeds cap", "user balance never negative", "sum of deposits equals contract balance"
- Complex state machines where the order of operations matters
- Complementary to unit tests — invariants catch bugs that specific scenarios miss

### Structure

```
test/invariant/
├── handlers/
│   └── CounterHandler.sol          ← actor that calls contract functions randomly
└── Counter.invariant.t.sol         ← defines invariants + configures handlers
```

### Handler

The handler wraps contract calls with valid inputs. Foundry calls handler functions randomly during invariant runs.

```solidity
// test/invariant/handlers/CounterHandler.sol

contract CounterHandler is Test {
    Counter internal counter;
    address internal owner;

    // ghost variables to track expected state
    uint256 public ghost_totalIncrements;

    constructor(Counter counter_, address owner_) {
        counter = counter_;
        owner = owner_;
    }

    function increment() external {
        counter.increment();
        ghost_totalIncrements++;
    }

    function setNumber(uint256 newNumber) external {
        vm.prank(owner);
        counter.setNumber(newNumber);
    }
}
```

### Invariant test

```solidity
// test/invariant/Counter.invariant.t.sol

contract CounterInvariantTest is Test, CounterBase {
    CounterHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new CounterHandler(counter, owner);

        // tell Foundry which contracts to call randomly
        targetContract(address(handler));
    }

    // invariant_ prefix is required
    function invariant_NumberNeverOverflows() external view {
        // if we got here without revert, the number is valid
        counter.number();
    }

    function invariant_CounterIsAlwaysInitialized() external view {
        assertEq(counter.owner(), owner);
    }
}
```

### Tips

- Use `targetContract()` to restrict which contracts Foundry calls — without it, Foundry calls random addresses
- Use **ghost variables** in handlers to track expected cumulative state
- Use `targetSelector()` if you want to restrict which functions are called
- Use `excludeContract()` to prevent calls to contracts that would break state (e.g. the proxy admin)
- Keep handler logic simple — its job is to make valid calls, not to test

---

## Running Tests

```bash
# All local tests (excludes fork)
npm run test:local

# Fork tests only
npm run test:fork

# All tests
npm run test

# Specific contract
forge test --match-contract CounterSetNumberTest -vvv

# Specific test function
forge test --match-test test_WhenNewNumberIsZero -vvv

# With gas report
forge test --gas-report -vvv

# Coverage
npm run coverage
```

Always run with `-vvv` to see debug traces on failure.

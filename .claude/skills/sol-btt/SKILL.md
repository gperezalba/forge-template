---
name: sol-btt
description: "[Solidity] Generate BTT (Branching Tree Technique) tests for a Solidity contract or function. Creates .tree specs, scaffolds with bulloak, and implements tests."
argument-hint: "<ContractName> [functionName]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Solidity — BTT Test Generation

Generate Branching Tree Technique tests for a Solidity contract.

**Input**: `$ARGUMENTS`
- `ContractName` — generate `.tree` + tests for ALL external/public functions
- `ContractName functionName` — generate `.tree` + test for ONE function

---

## Phase 1: Discovery

1. Parse `$ARGUMENTS` to determine if this is a full contract or single function
2. Read the contract source: `src/<ContractName>.sol`
3. Read the interface: `src/interfaces/I<ContractName>.sol` (errors, events, function signatures)
4. Read the test base if it exists: `test/<ContractName>Base.t.sol`
5. Read the root base: `test/Base.t.sol` (available accounts: `owner`, `nonOwner`, etc.)
6. If the contract inherits from `UUPSOwnable2Step`, read `src/utils/proxy/UUPSOwnable2Step.sol` for inherited functions
7. Identify all target functions:
   - If single function mode: just that function
   - If full contract mode: all `external` and `public` functions declared in the contract (not inherited unless overridden)

---

## Phase 2: Generate `.tree` files

For each target function, generate a `.tree` file at `test/unit/<ContractName>/functionName.tree`.

### Tree syntax rules

```
functionName.tree
├── given <pre-existing contract state>
│   ├── when <parameter/input condition>
│   │   ├── it should <expected behavior>
│   │   └── it should <another behavior>
│   └── when <another input condition>
│       └── it should <behavior>
└── given <another state>
    └── it should <behavior>
```

### Node semantics

- **`given`** = contract state/storage BEFORE the call. Use for: caller identity, paused/unpaused, balances, initialized/not, storage values
- **`when`** = function parameters or inputs AT call time. Use for: parameter values, zero/nonzero, boundary values
- **`it should`** = leaf assertion. Always a leaf node, never has children

### Coverage categories (check ALL of these for every function)

1. **Access control**: Who can call? (owner, non-owner, admin, anyone). If `onlyOwner` or role-restricted, branch on caller identity first
2. **Parameter boundaries**: Zero, typical value, edge values (max uint256, address(0)), empty arrays/bytes
3. **State preconditions**: What storage state affects behavior? (initialized/not, paused/not, balance exists/empty)
4. **Revert paths**: Every `if (...) revert`, `require`, custom error, overflow/underflow. Each MUST have its own branch
5. **Happy paths**: Each distinct successful execution path with different state transitions
6. **Events**: If the function emits events, include `it should emit <EventName>` as a leaf
7. **State changes**: Include `it should update the storage correctly` or similar for verifiable state mutations

### Naming collision prevention

When the same `when` condition appears under different `given` branches, suffix with context to make test function names unique:

```
├── given the caller is the owner
│   └── when newNumber is zero as owner        ← suffix "as owner"
└── given the caller is not the owner
    └── when newNumber is zero as non-owner    ← suffix "as non-owner"
```

### Special cases

**Initializer functions** (`initialize`):
- Branch on `given the contract is not initialized` vs `given the contract is already initialized`
- Under "not initialized": branch on each parameter validation (zero address, valid address)
- Under "already initialized": `it should revert with InvalidInitialization`

**View/pure functions** (getters):
- Branch on different storage states: `given the number is zero`, `given the number is a positive value`, `given the number is the maximum uint256 value`

**Functions with no parameters and no access control** (like `increment`):
- Branch only on `given` state conditions that affect behavior

---

### STOP AND ASK FOR APPROVAL

After generating ALL `.tree` files, **show them to the user** and ask:

> "Here are the generated `.tree` files. Review them and let me know if you want to adjust any branches before I scaffold and implement the tests."

**Do NOT proceed to Phase 3 until the user approves the `.tree` files.**

---

## Phase 3: Scaffold with bulloak

For each approved `.tree` file:

```bash
bulloak scaffold -w -s 0.8.24 test/unit/<ContractName>/functionName.tree
```

This generates `functionName.t.sol` alongside the `.tree` file.

---

## Phase 4: Implement tests

### Pre-checks before implementing

- If `test/<ContractName>Base.t.sol` does NOT exist, **create it first** following this pattern:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Base} from "test/Base.t.sol";
import {ContractName} from "src/ContractName.sol";

contract ContractNameBase is Base {
    ContractName public contractName;

    function setUp() public virtual override {
        super.setUp();
        contractName = ContractName(deployReport.proxies.contractName);
        vm.label(address(contractName), "contractNameProxy");
    }
}
```

### Implementation rules for each `.t.sol` file

1. **Replace** the scaffold's contract declaration with proper inheritance:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol"; // if needed for OZ errors
import {ContractNameBase} from "test/ContractNameBase.t.sol";
import {ContractName} from "src/ContractName.sol";
import {IContractName} from "src/interfaces/IContractName.sol"; // for custom errors

contract ContractNameFunctionNameTest is Test, ContractNameBase {
    ContractName internal testContract;

    function setUp() public override {
        super.setUp();
        testContract = contractName; // from ContractNameBase
    }

    // ... modifiers and tests from scaffold
}
```

2. **Keep scaffold structure intact**: Do NOT rename generated functions or modifiers. Do NOT remove `it should` comments.

3. **Implement modifiers** — fill empty bodies:

```solidity
// Access control
modifier givenTheCallerIsTheOwner() {
    vm.startPrank(owner);
    _;
    vm.stopPrank();
}

modifier givenTheCallerIsNotTheOwner() {
    vm.startPrank(nonOwner);
    _;
    vm.stopPrank();
}

// State setup
modifier givenTheContractIsPaused() {
    vm.prank(admin);
    testContract.pause();
    _;
}

// Fresh deployment (for initialize tests)
modifier givenTheContractIsNotInitialized() {
    testContract = ContractName(address(new ERC1967Proxy(address(new ContractName()), "")));
    _;
}

modifier givenTheContractIsAlreadyInitialized() {
    testContract = contractName; // already initialized from fixture
    _;
}
```

4. **Implement test functions** following Arrange-Act-Assert:

```solidity
// Happy path
function test_WhenNewNumberIsAPositiveValueAsOwner() external givenTheCallerIsTheOwner {
    uint256 newNumber = 42;

    testContract.setNumber(newNumber);

    // it should set number to newNumber
    assertEq(testContract.number(), newNumber);
    // it should update the storage correctly
    assertEq(testContract.number(), 42);
}

// Revert with custom error (no params)
function test_WhenOwner_IsTheZeroAddress() external givenTheContractIsNotInitialized {
    // it should revert with ContractName_ZeroAddress
    vm.expectRevert(abi.encodeWithSelector(IContractName.ContractName_ZeroAddress.selector));
    testContract.initialize(address(0));
}

// Revert with OZ error (with params)
function test_WhenNewNumberIsZeroAsNon_owner() external givenTheCallerIsNotTheOwner {
    // it should revert with OwnableUnauthorizedAccount
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
    testContract.setNumber(0);
}

// Arithmetic overflow
function test_GivenTheCurrentNumberIsTheMaximumUint256Value() external {
    vm.prank(owner);
    testContract.setNumber(type(uint256).max);

    // it should revert with arithmetic overflow error
    vm.expectRevert();
    testContract.increment();
}

// Event emission
function test_EmitWhen_NumberChanged() external givenTheCallerIsTheOwner {
    // Declare event in test contract or import from interface
    vm.expectEmit(true, true, true, false);
    emit NumberChanged(0, 42, owner);
    testContract.setNumber(42);
}
```

5. **Import rules**:
   - `abi.encodeWithSelector` with OZ errors: import the specific OZ contract (`Ownable`, `Initializable`)
   - `abi.encodeWithSelector` with custom errors: import the interface (`IContractName`)
   - For initialize tests with fresh proxy: import `ERC1967Proxy` from OZ
   - ALWAYS use `abi.encodeWithSelector` for reverts with parameters, NEVER raw `vm.expectRevert(ContractName_Error.selector)`

---

## Phase 5: Validate

After implementing all tests:

```bash
# Verify tree-test sync
bulloak check test/unit/<ContractName>/*.tree

# Run the new tests
forge test --match-contract <ContractName> -vvv
```

If any test fails, fix it before finishing. If `bulloak check` reports mismatches, resolve them.

---

## Summary of generated files

For a full contract run, the skill produces:
- `test/<ContractName>Base.t.sol` (if it didn't exist)
- `test/unit/<ContractName>/functionA.tree`
- `test/unit/<ContractName>/functionA.t.sol`
- `test/unit/<ContractName>/functionB.tree`
- `test/unit/<ContractName>/functionB.t.sol`
- ... one pair per external/public function

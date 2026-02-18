# Branching Tree Technique (BTT) Tests

Reference: [PaulRBerg/btt-examples](https://github.com/PaulRBerg/btt-examples)

## Overview

BTT is a structured methodology for writing Solidity tests in Foundry projects. The workflow is:

1. **Write a `.tree` file** that specifies all execution paths of a function
2. **Run `bulloak scaffold`** to generate the test skeleton (`.t.sol`)
3. **Implement** the generated test functions with actual logic

The `.tree` file is the single source of truth. If the tree is well-designed, the scaffold produces a clean, complete test structure that only needs implementation.

---

## 1. The `.tree` File

### File Naming & Location

- One `.tree` file per function being tested
- Named after the function: `functionName.tree`
- Located in `test/unit/<ContractName>/functionName.tree`
- Example: `test/unit/Counter/setNumber.tree`

### Syntax

Tree files use ASCII art to represent a branching decision tree:

```
functionName.tree
├── given <condition about contract state>
│   ├── when <condition about parameters/external input>
│   │   ├── it should <expected behavior>
│   │   └── it should <another expected behavior>
│   └── when <another parameter condition>
│       └── it should <expected behavior>
└── given <another state condition>
    └── it should <expected behavior>
```

Use the characters `├──`, `└──`, and `│` for the tree structure. The root node is always the filename itself.

### Node Types

There are exactly three types of nodes:

| Node | Keyword | Meaning | Becomes in scaffold |
|------|---------|---------|---------------------|
| **given** | `given` | Contract state/storage that exists **before** the function call | `modifier` |
| **when** | `when` | Function parameters, user input, or external call conditions | `modifier` |
| **it should** | `it should` | Expected behavior — the actual assertion | `comment` inside test function |

### Semantic Rules

#### `given` = Pre-existing state

Use `given` for conditions that describe the contract's state/storage **before** the function is called. These are things the test must **set up**.

Examples:
- `given the caller is the owner` (msg.sender context)
- `given the contract is paused` (storage state)
- `given the user has a balance of 100` (storage state)
- `given the current number is zero` (storage state)
- `given the contract is not initialized` (deployment state)

#### `when` = Input/parameter conditions

Use `when` for conditions about the function's parameters or external inputs that the caller controls **at call time**.

Examples:
- `when newNumber is zero` (function parameter)
- `when the amount is greater than balance` (function parameter)
- `when the token address is the zero address` (function parameter)
- `when owner_ is the zero address for first initialization` (function parameter)

#### `it should` = Assertions

Leaf nodes that describe what the test must verify. These become comments in the scaffold.

Examples:
- `it should set number to zero`
- `it should revert with OwnableUnauthorizedAccount`
- `it should emit a Transfer event`
- `it should update the storage correctly`

### Nesting Rules

- `given` nodes are typically at the **first level** of branching (closest to root)
- `when` nodes are nested **inside** `given` nodes when both are needed
- `it should` nodes are always **leaf nodes** (no children)
- A `given` can contain other `given` nodes, `when` nodes, or `it should` nodes
- A `when` can contain other `when` nodes or `it should` nodes
- `it should` never contains children

### Common patterns

#### Simple function (no access control, few states)

```
increment.tree
├── given the current number is zero
│   └── it should increment number to one
├── given the current number is a positive value less than max uint256
│   └── it should increment number by one
└── given the current number is the maximum uint256 value
    └── it should revert with arithmetic overflow error
```

#### Function with access control

```
setNumber.tree
├── given the caller is the owner
│   ├── when newNumber is zero
│   │   └── it should set number to zero
│   └── when newNumber is a positive value
│       └── it should set number to newNumber
└── given the caller is not the owner
    └── when newNumber is any value
        └── it should revert with OwnableUnauthorizedAccount
```

#### Initializer function

```
initialize.tree
├── given the contract is not initialized
│   ├── when owner_ is the zero address
│   │   └── it should revert with CustomError
│   └── when owner_ is a valid address
│       ├── it should set the owner correctly
│       └── it should complete initialization successfully
└── given the contract is already initialized
    └── it should revert with InvalidInitialization
```

---

## 2. Design Guidelines for Complete Coverage

### Think in execution paths

Before writing the tree, trace every `if`, `require`, `revert`, and state-dependent branch in the Solidity function. Each one becomes a path in the tree.

### Cover these categories systematically

1. **Access control**: Who can call? (owner, non-owner, specific role, anyone)
2. **Parameter boundaries**: Zero, typical value, edge values, max value
3. **State preconditions**: What contract state affects behavior? (initialized/not, paused/not, balance exists/not)
4. **Revert paths**: Every `require`, `revert`, custom error, and arithmetic overflow
5. **Happy paths**: Every successful execution with distinct state transitions
6. **Events**: If the function emits events, include `it should emit EventName`

### Naming conventions in tree nodes

- Be descriptive enough that the generated test function name is self-documenting
- Include context to avoid ambiguous function names in the scaffold
- For access-controlled functions, suffix `when` nodes with the caller context: `when newNumber is zero as owner` vs `when newNumber is zero as non-owner`
- This prevents naming collisions in the generated test functions

### Avoid these mistakes

| Mistake | Why it's a problem |
|---------|-------------------|
| Using `when` for contract state | `when` is for inputs; use `given` for state that must be set up before the call |
| Using `given` for function parameters | `given` is for pre-existing state; use `when` for call-time decisions |
| Missing revert paths | Every `require`/`revert` in the code must have a corresponding branch |
| Duplicate leaf descriptions across branches | Can generate duplicate function names in scaffold |
| Too few boundary values | Miss edge cases like zero, max uint256, empty arrays |
| Forgetting overflow/underflow cases | Solidity 0.8+ reverts on overflow — test it |

---

## 3. Running the Scaffold

### Generate test skeleton

```bash
# Preview to stdout
bulloak scaffold test/unit/Counter/setNumber.tree

# Write to file (creates setNumber.t.sol alongside the .tree)
bulloak scaffold -w test/unit/Counter/setNumber.tree

# Write with specific Solidity version
bulloak scaffold -w -s 0.8.24 test/unit/Counter/setNumber.tree

# Force overwrite existing .t.sol
bulloak scaffold -w -f test/unit/Counter/setNumber.tree
```

### What the scaffold generates

For each `.tree` file, bulloak generates a `.t.sol` file with:

- A contract named after the tree file
- **Modifiers** for each `given`/`when` branch (empty body with `_;`)
- **Test functions** for each path, with:
  - The correct modifier chain applied
  - `it should` lines as comments inside the function body
  - Empty implementation (to be filled in)

Example scaffold output for `setNumber.tree`:

```solidity
contract setNumbertree {
    modifier givenTheCallerIsTheOwner() {
        _;
    }

    function test_WhenNewNumberIsZeroAsOwner() external givenTheCallerIsTheOwner {
        // it should set number to zero
        // it should update the storage correctly
    }

    modifier givenTheCallerIsNotTheOwner() {
        _;
    }

    function test_WhenNewNumberIsZeroAsNon_owner() external givenTheCallerIsNotTheOwner {
        // it should revert with OwnableUnauthorizedAccount
    }
}
```

### Validate tree-to-test sync

```bash
# Check that .t.sol matches .tree spec
bulloak check test/unit/Counter/setNumber.tree

# Auto-fix mismatches (add missing tests/modifiers)
bulloak check --fix test/unit/Counter/setNumber.tree
```

---

## 4. Implementing the Tests

After the scaffold is generated, the implementation follows these patterns:

### Contract structure

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

// solhint-disable

import {Test} from "forge-std/Test.sol";
import {ContractBase} from "test/ContractBase.t.sol";
import {TargetContract} from "src/TargetContract.sol";

contract TargetFunctionTest is Test, ContractBase {
    TargetContract internal testContract;

    function setUp() public override {
        super.setUp();
        testContract = deployedContract; // from fixture
    }

    // ... modifiers and tests
}
```

### Implement modifiers

Fill in the empty modifiers with actual state setup:

```solidity
modifier givenTheCallerIsTheOwner() {
    vm.startPrank(owner);
    _;
    vm.stopPrank();
}

modifier givenTheContractIsPaused() {
    vm.prank(owner);
    testContract.pause();
    _;
}
```

### Implement test functions

Follow the **Arrange-Act-Assert** pattern:

```solidity
function test_WhenNewNumberIsAPositiveValue() external givenTheCallerIsTheOwner {
    // ARRANGE
    uint256 newNumber = 42;

    // ACT
    testContract.setNumber(newNumber);

    // ASSERT
    // it should set number to newNumber
    assertEq(testContract.number(), newNumber);
    // it should update the storage correctly
    assertEq(testContract.number(), 42);
}
```

### Revert tests

```solidity
// Simple revert
function test_WhenCallerIsNotOwner() external givenTheCallerIsNotTheOwner {
    // it should revert with OwnableUnauthorizedAccount
    vm.expectRevert(
        abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner)
    );
    testContract.setNumber(42);
}
```

### Event tests

```solidity
function test_EmitWhen_OwnershipTransferred() external {
    // it should emit OwnershipTransferred
    vm.expectEmit(true, true, false, false);
    emit OwnershipTransferred(address(0), owner);
    // ... action that emits
}
```

### Testing initializers (UUPS proxy pattern)

For `initialize` functions, deploy a fresh proxy instead of using the fixture:

```solidity
function test_WhenOwnerIsValid() external {
    // Deploy fresh implementation + proxy (not from fixture)
    TargetContract impl = new TargetContract();
    ERC1967Proxy proxy = new ERC1967Proxy(address(impl), "");
    TargetContract freshContract = TargetContract(address(proxy));

    // Now test initialization
    freshContract.initialize(owner);
    assertEq(freshContract.owner(), owner);
}
```

---

## 5. Quick Reference

### Full workflow

```bash
# 1. Write the .tree file
#    test/unit/MyContract/myFunction.tree

# 2. Scaffold
bulloak scaffold -w -s 0.8.24 test/unit/MyContract/myFunction.tree

# 3. Implement tests in the generated .t.sol

# 4. Run tests
forge test --match-contract MyContractMyFunctionTest -vvv

# 5. Validate tree/test sync
bulloak check test/unit/MyContract/myFunction.tree
```

### Test naming conventions

| Tree node pattern | Generated function name |
|---|---|
| `given X` → `it should Y` | `test_GivenX()` |
| `given X` → `when Y` → `it should Z` | `test_WhenY()` with `givenX` modifier |
| `it should revert with Error` | `test_RevertWhen_...()` (name it manually) |
| Fuzz test | `testFuzz_...()` |
| Event emission test | `test_EmitWhen_...()` |

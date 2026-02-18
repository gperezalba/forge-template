# Naming Conventions

Enforced by `.solhint.json` rules and project convention.

---

## 1. Files

| Type | Extension | Naming | Example |
|------|-----------|--------|---------|
| Production contract | `.sol` | PascalCase, matches contract name | `Counter.sol` |
| Interface | `.sol` | `I` + ContractName | `ICounter.sol` |
| Test file | `.t.sol` | camelCase function name (unit) or PascalCase description | `setNumber.t.sol`, `SafeSingletonFactory.t.sol` |
| Test base | `.t.sol` | PascalCase + `Base` | `CounterBase.t.sol`, `Base.t.sol` |
| Script file | `.s.sol` | PascalCase, describes action | `DeploySepoliaDEV.s.sol` |
| Config file | `.sol` | PascalCase (no `.s.sol` — not executable) | `ConfigAbstract.sol`, `ConfigSepoliaDEV.sol` |
| Deployment helpers | `.sol` | PascalCase (no `.s.sol` — not executable) | `DeployContracts.sol` |
| Tree spec | `.tree` | camelCase function name | `setNumber.tree` |
| Mock | `.sol` | PascalCase + `Mock` | `ERC20Mock.sol` |

**Key rule**: Only files with a `run()` entry point get the `.s.sol` extension. Abstract bases and pure logic contracts use plain `.sol`.

---

## 2. Contracts & Interfaces

All use **PascalCase**.

| Type | Pattern | Example |
|------|---------|---------|
| Production contract | `<Name>` | `Counter`, `Deployer` |
| Interface | `I<ContractName>` | `ICounter` |
| Abstract base | `<Name>` or `<Name>Abstract` | `UUPSOwnable2Step`, `ConfigAbstract` |
| Library | `<Name>Utils` | `Create2Utils` |
| Mock | `<Name>Mock` | `ERC20Mock` |
| Test contract | `<Contract><Function>Test` | `CounterSetNumberTest` |
| Test base | `<Contract>Base` | `CounterBase`, `Base` |
| Invariant handler | `<Contract>Handler` | `CounterHandler` |
| Fork test | `<Name>ForkTest` | `SafeSingletonFactoryForkTest` |
| Deploy script | `Deploy<Chain><Env>` | `DeploySepoliaDEV`, `DeployPolygon` |
| Deploy base | `DeployBase`, `SingleDeployBase` | |
| Config | `Config<Chain><Env>` | `ConfigSepoliaDEV`, `ConfigPolygon` |
| Workflow ecosystem | `Ecosystem` | |
| Workflow action | `<Contract><Action>` | `CounterSetNumber` |

---

## 3. Functions

| Visibility | Pattern | Example |
|------------|---------|---------|
| `external` / `public` | camelCase | `setNumber()`, `increment()`, `deploy()` |
| `internal` | `_camelCase` (leading underscore) | `_deployContracts()`, `_getInitialConfig()` |
| `private` | `_camelCase` (leading underscore) | `_authorizeUpgrade()` |
| Initializer (OZ pattern) | `__Name_init` | `__UUPSOwnable2Step_init()`, `__Ownable_init()` |
| Script entry point | `run()` | Always `run()` for Foundry scripts |
| Test setup | `setUp()` | Foundry convention |

---

## 4. Test Functions

| Type | Prefix | Example |
|------|--------|---------|
| Standard | `test_` | `test_GivenTheCurrentNumberIsZero()` |
| Fuzz | `testFuzz_` | `testFuzz_SetNumberAnyValue(uint256)` |
| Revert | `test_RevertWhen_` | `test_RevertWhen_CallerNotOwner()` |
| Fuzz revert | `testFuzz_RevertWhen_` | `testFuzz_RevertWhen_InvalidAmount(uint256)` |
| Event | `test_EmitWhen_` | `test_EmitWhen_NumberChanged()` |
| Fork | `testFork_` | `testFork_SafeSingletonFactoryIsDeployed()` |
| Invariant | `invariant_` | `invariant_BalanceAlwaysPositive()` |

**BTT-generated names** follow the tree node text converted to PascalCase:

```
tree:  "given the caller is the owner" → "when newNumber is zero as owner"
test:  test_WhenNewNumberIsZeroAsOwner()  +  modifier givenTheCallerIsTheOwner()
```

---

## 5. Variables

### State Variables

| Visibility | Pattern | Example |
|------------|---------|---------|
| `public` | camelCase | `uint256 public number` |
| `internal` | camelCase | `Counter internal counter` |
| `private` | `_camelCase` (leading underscore) | `bool private _deployed` |

**Solhint enforces**: `private-vars-leading-underscore: error`

### Local Variables

Always camelCase, no prefix:

```solidity
uint256 newNumber = 42;
address newOwner = makeAddr("owner");
string memory version = "1.0.0";
bytes32 salt = keccak256(...);
```

### Function Parameters

camelCase. Use **trailing underscore** when a parameter shadows a state variable or function:

```solidity
function initialize(address owner_) external    // owner_ avoids shadowing owner()
function setNumber(uint256 newNumber) external   // no shadow, no underscore needed
```

---

## 6. Constants & Immutables

| Type | Pattern | Example |
|------|---------|---------|
| `public constant` | `UPPER_CASE` | `address public constant SAFE_SINGLETON_FACTORY = 0x...` |
| `public immutable` | `UPPER_CASE` | `Counter public immutable COUNTER` |
| `private constant` | `UPPER_CASE` | `Vm private constant VM = ...` |
| `internal constant` | `_UPPER_CASE` (leading underscore) | `address internal constant _OWNER = 0x...` |

**Rule**: Constants and immutables are always `UPPER_CASE`. Internal/private ones get the `_` prefix.

---

## 7. Modifiers

Always camelCase.

### Production modifiers

Standard descriptive names:

```solidity
modifier onlyOwner() { ... }
modifier onlyInitializing() { ... }
modifier whenNotPaused() { ... }
```

### Test modifiers (BTT)

Named after the `given`/`when` node from the `.tree` file:

```solidity
modifier givenTheCallerIsTheOwner() {
    vm.startPrank(owner);
    _;
    vm.stopPrank();
}

modifier givenTheContractIsNotInitialized() {
    _;
}
```

---

## 8. Custom Errors

**Pattern**: `ContractName_ErrorDescription`

```solidity
error Counter_ZeroAddress();
error Deployer_Unauthorized();
error Deployer_AlreadyDeployed();
```

- Defined in the **interface** (e.g., `ICounter`)
- PascalCase for both parts, separated by `_`
- No parameters unless needed: `error Vault_InsufficientBalance(uint256 available, uint256 requested)`

---

## 9. Events

**PascalCase**, verb or noun describing the state change:

```solidity
event Deploy(address indexed counter);
event NumberChanged(uint256 indexed oldNumber, uint256 indexed newNumber);
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
```

- Use `indexed` for commonly filtered fields (addresses, IDs)
- Past tense or action noun (`Deployed`, `Transfer`, `Paused`)

---

## 10. Structs & Enums

### Structs

**PascalCase** for the type, **camelCase** for fields:

```solidity
struct Config {
    address owner;
    Environment env;
    Deployer.Config deployerConfig;
}

struct Addresses {
    address counter;
}

struct Report {
    Deployer.Config deployerConfig;
    Deployer.Addresses implementations;
    Deployer.Addresses proxies;
    address deployer;
}
```

### Enums

**PascalCase** for the type, **UPPER_CASE** for values:

```solidity
enum Environment {
    DEV,
    INT,
    STA,
    PRO
}
```

---

## Quick Reference Table

| Element | Convention | Example |
|---------|-----------|---------|
| Contract | PascalCase | `Counter` |
| Interface | `I` + PascalCase | `ICounter` |
| File (contract) | PascalCase`.sol` | `Counter.sol` |
| File (test) | camelCase`.t.sol` | `setNumber.t.sol` |
| File (script) | PascalCase`.s.sol` | `DeploySepoliaDEV.s.sol` |
| Public function | camelCase | `setNumber()` |
| Internal function | `_`camelCase | `_deployContracts()` |
| Public variable | camelCase | `number` |
| Private variable | `_`camelCase | `_deployed` |
| Constant/immutable | `UPPER_CASE` | `SAFE_SINGLETON_FACTORY` |
| Internal constant | `_UPPER_CASE` | `_OWNER` |
| Parameter | camelCase (trailing `_` if shadows) | `owner_`, `newNumber` |
| Modifier | camelCase | `onlyOwner`, `givenTheCallerIsTheOwner` |
| Custom error | `Contract_Error` | `Counter_ZeroAddress` |
| Event | PascalCase | `Deploy`, `NumberChanged` |
| Struct | PascalCase | `Config`, `Addresses` |
| Enum type | PascalCase | `Environment` |
| Enum value | UPPER_CASE | `DEV`, `PRO` |
| Test function | `test_`PascalCase | `test_GivenTheCurrentNumberIsZero` |
| Fuzz test | `testFuzz_`PascalCase | `testFuzz_SetNumber` |
| Fork test | `testFork_`PascalCase | `testFork_FactoryIsDeployed` |
| Invariant test | `invariant_`PascalCase | `invariant_BalancePositive` |

# NatSpec Documentation

Rules for documenting Solidity code with NatSpec comments.

---

## General Principles

- Document **why**, not what — the code already shows the what
- `@notice` is for users/consumers of the contract (what does this do?)
- `@dev` is for developers modifying the code (non-obvious implementation details)
- Use `@dev` sparingly — if the code is clear, `@notice` alone is enough
- Every `external` and `public` element must have NatSpec
- `internal` and `private` elements: `@notice` or `@dev` at minimum

---

## Contracts & Interfaces

Always include `@title`, `@author`, `@notice`:

```solidity
/// @title Counter
/// @author gperezalba
/// @notice Upgradeable counter contract with owner-restricted set and public increment
contract Counter is UUPSOwnable2Step, ICounter {
```

Add `@dev` when there's an architectural note. Add `@custom:security-contact` on base/core contracts:

```solidity
/// @title UUPSOwnable2Step
/// @author gperezalba
/// @notice Implementation of UUPS proxy pattern with two-step ownership transfer
/// @dev Combines UUPSUpgradeable with Ownable2StepUpgradeable for secure upgradeable contracts
/// @custom:security-contact security@yourproject.com
contract UUPSOwnable2Step is UUPSUpgradeable, Ownable2StepUpgradeable {
```

Interfaces follow the same pattern:

```solidity
/// @title ICounter
/// @author gperezalba
/// @notice Interface for the Counter contract
interface ICounter {
```

---

## Functions

### External / Public

Always: `@notice` + `@param` for every parameter + `@return` for every return value.

```solidity
/// @notice Sets the stored number to a new value
/// @param newNumber The new value to store
function setNumber(uint256 newNumber) public onlyOwner {
```

```solidity
/// @notice Creates an ERC1967 proxy pointing to the given implementation
/// @param proxyImplementation Address of the implementation contract
/// @param initializeCalldata Encoded initializer call
/// @return proxyAddress Address of the newly created proxy
function _createProxy(address proxyImplementation, bytes memory initializeCalldata)
    internal
    returns (address proxyAddress)
{
```

Add `@dev` only for non-obvious details:

```solidity
/// @notice Gets the address of the current implementation
/// @dev Uses ERC1967Utils to retrieve the implementation address
/// @return The address of the current implementation contract
function implementation() external view returns (address) {
```

### No-parameter, no-return functions

Just `@notice`:

```solidity
/// @notice Increments the stored number by one
function increment() public {
```

### Initializers

```solidity
/// @notice Initializes the contract setting the owner and upgradeability
/// @param owner_ Address of the contract owner
function initialize(address owner_) public initializer {
```

For OZ-style internal initializers, use `@dev` for technical context:

```solidity
/// @notice Initializes the contract
/// @dev Empty initialization as core initialization is handled by parent contracts
function __UUPSOwnable2Step_init() internal onlyInitializing {
```

### Overrides

Document only if the override adds behavior. If it just restricts access or is empty, a short `@dev` suffices:

```solidity
/// @notice Authorizes an upgrade to a new implementation
/// @dev Can only be called by the owner
/// @param newImplementation Address of the new implementation contract
function _authorizeUpgrade(address newImplementation) internal view virtual override onlyOwner {}
```

---

## State Variables

`@notice` for public variables (they generate getters, so this is user-facing):

```solidity
/// @notice The current stored number
uint256 public number;

/// @notice Address authorized to trigger the deployment
address public immutable AUTHORIZED;
```

`@dev` for private/internal variables that need context:

```solidity
/// @dev Whether the deployment has already been executed
bool private _deployed;
```

---

## Custom Errors

`@notice` describing **when** the error is thrown:

```solidity
/// @notice Thrown when the provided address is the zero address
error Counter_ZeroAddress();

/// @notice Thrown when the caller is not the authorized deployer
error Deployer_Unauthorized();

/// @notice Thrown when deploy is called more than once
error Deployer_AlreadyDeployed();
```

For errors with parameters, add `@param`:

```solidity
/// @notice Thrown when withdrawal exceeds available balance
/// @param available The current balance
/// @param requested The amount requested
error Vault_InsufficientBalance(uint256 available, uint256 requested);
```

---

## Events

`@notice` for the event, `@param` for each field:

```solidity
/// @notice Emitted when the deployment is executed
/// @param counter Address of the deployed Counter proxy
event Deploy(address indexed counter);
```

```solidity
/// @notice Emitted when the stored number changes
/// @param oldNumber The previous value
/// @param newNumber The new value
/// @param caller The address that triggered the change
event NumberChanged(uint256 indexed oldNumber, uint256 indexed newNumber, address indexed caller);
```

---

## Structs & Enums

`@notice` on the type, optionally `@param` on fields if not self-explanatory:

```solidity
/// @notice Addresses of the contract implementations or proxies
struct Addresses {
    address counter;
}

/// @notice Configuration for the deployment
struct Config {
    address owner;
}
```

Enums:

```solidity
/// @notice Lifecycle stages of a vault
enum Status {
    Funding,
    Active,
    Closed
}
```

---

## Custom Tags

| Tag | Where | Purpose |
|-----|-------|---------|
| `@custom:security-contact` | Contract-level | Security contact email |
| `@custom:oz-upgrades-unsafe-allow` | Function/constructor-level | Suppress OZ upgrades safety checks |

---

## What NOT to Document

- Obvious getters that just return a named variable — `@notice` on the variable is enough
- Import statements
- `// solhint-disable` pragmas
- Test files (`// solhint-disable` at the top, no NatSpec required)
- Script files (optional, NatSpec on the contract is enough)

---

## Quick Reference

| Element | Required tags | Optional |
|---------|--------------|----------|
| Contract | `@title`, `@author`, `@notice` | `@dev`, `@custom:*` |
| Interface | `@title`, `@author`, `@notice` | `@dev` |
| External function | `@notice`, `@param`, `@return` | `@dev` |
| Public function | `@notice`, `@param`, `@return` | `@dev` |
| Internal function | `@notice` or `@dev` | `@param`, `@return` |
| Private function | `@dev` | `@param`, `@return` |
| State variable (public) | `@notice` | `@dev` |
| State variable (private) | `@dev` | — |
| Error | `@notice` | `@param` |
| Event | `@notice`, `@param` | `@dev` |
| Struct | `@notice` | `@param` |
| Enum | `@notice` | — |

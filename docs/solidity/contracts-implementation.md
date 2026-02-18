# Contracts Implementation

Concise reference for writing production smart contracts. Each section is a rule — follow it unless there's a documented reason not to.

---

## Proxy Pattern & Upgradeability

- All contracts use **UUPS proxy** (`UUPSUpgradeable` + `Ownable2StepUpgradeable`) via the `UUPSOwnable2Step` base.
- Never use constructors for state initialization. Use `initialize()` with the `initializer` modifier.
- Call all parent initializers explicitly: `__Ownable_init`, `__Ownable2Step_init`, `__UUPSUpgradeable_init`, `__UUPSOwnable2Step_init`.
- **Initialize implementations on deploy** — call `initialize` on the implementation too (with a throwaway owner or `address(1)`) to prevent anyone from initializing it and self-destructing it.
- `_authorizeUpgrade` must be `onlyOwner`. The owner is a **highly restrictive multisig** — upgrades are the most sensitive operation.
- Never add `selfdestruct` or `delegatecall` to arbitrary targets in implementation contracts.

---

## Access Control

### Two-tier model

| Role | Who | Permissions | Multisig threshold |
|------|-----|-------------|-------------------|
| **Owner** | Highly restrictive multisig | `upgradeToAndCall`, transfer ownership | High (e.g. 4/6) |
| **Admin** | Less restrictive multisig | Operational functions: pause, set parameters, grant roles | Lower (e.g. 2/4) |

- Use `Ownable2StepUpgradeable` for ownership (prevents accidental transfer to wrong address).
- Use `AccessControlUpgradeable` when you need multiple roles beyond owner/admin.
- Never mix upgrade authority with daily operations — keep them in separate roles.

### Modifiers backed by internal functions

Prefer extracting modifier logic to an internal function to avoid code duplication when the same check is needed elsewhere:

```solidity
modifier onlyAdmin() {
    _checkAdmin();
    _;
}

function _checkAdmin() internal view {
    if (msg.sender != admin) revert Contract_Unauthorized();
}
```

---

## Function Order

Follow this order inside a contract:

```solidity
contract MyContract {
    // 1. State variables (constants, immutables, then storage)
    // 2. Events
    // 3. Errors (or in interface)
    // 4. Modifiers
    // 5. Constructor / initialize
    // 6. External functions
    // 7. Public functions
    // 8. Internal functions
    // 9. Private functions
}
```

Within each visibility group: state-changing functions first, then `view`, then `pure`.

---

## Checks-Effects-Interactions (CEI)

Every state-changing function must follow this order:

```solidity
function withdraw(uint256 amount) external {
    // 1. CHECKS — validate inputs and state
    if (amount == 0) revert Vault_ZeroAmount();
    if (balances[msg.sender] < amount) revert Vault_InsufficientBalance();

    // 2. EFFECTS — update state BEFORE external calls
    balances[msg.sender] -= amount;

    // 3. INTERACTIONS — external calls last
    token.safeTransfer(msg.sender, amount);
}
```

Never update state after an external call. If you must interact with an untrusted contract, use ReentrancyGuard as an additional layer.

---

## Custom Errors

Always use custom errors. Never use `require` with string messages.

```solidity
// In the interface
error Counter_ZeroAddress();
error Vault_InsufficientBalance(uint256 available, uint256 requested);

// In the contract
if (owner_ == address(0)) revert Counter_ZeroAddress();
```

- Format: `ContractName_ErrorDescription`
- Define errors in the **interface**, not the contract
- Include parameters when useful for debugging

---

## Events

Emit events for **every** state change. Include enough data to reconstruct state off-chain without reading storage.

```solidity
event NumberChanged(uint256 indexed oldNumber, uint256 indexed newNumber, address indexed caller);

function setNumber(uint256 newNumber) external onlyOwner {
    uint256 oldNumber = number;
    number = newNumber;
    emit NumberChanged(oldNumber, newNumber, msg.sender);
}
```

- Use `indexed` for fields that will be filtered (addresses, IDs, statuses)
- Maximum 3 indexed parameters per event
- Emit **after** the state change, before external interactions

---

## Pausability

Use `PausableUpgradeable` for contracts that handle value or critical operations.

```solidity
function deposit(uint256 amount) external whenNotPaused { ... }
function withdraw(uint256 amount) external whenNotPaused { ... }

function pause() external onlyAdmin { _pause(); }
function unpause() external onlyAdmin { _unpause(); }
```

- `pause`/`unpause` belong to the **admin** role, not the owner
- Emergency pause should be fast — low multisig threshold
- Not everything needs to be pausable — view functions and upgrades should remain accessible

---

## Pull Over Push Payments

Never send ETH/tokens directly in a loop or to multiple recipients. Let users withdraw.

```solidity
// BAD — push
for (uint256 i; i < recipients.length; i++) {
    token.safeTransfer(recipients[i], amounts[i]); // one failure blocks all
}

// GOOD — pull
mapping(address => uint256) public pendingWithdrawals;

function withdraw() external {
    uint256 amount = pendingWithdrawals[msg.sender];
    if (amount == 0) revert Contract_NothingToWithdraw();
    pendingWithdrawals[msg.sender] = 0;
    token.safeTransfer(msg.sender, amount);
}
```

---

## Safe Patterns

### ERC20 interactions

Always use `SafeERC20`:

```solidity
using SafeERC20 for IERC20;

token.safeTransfer(to, amount);
token.safeTransferFrom(from, to, amount);
token.forceApprove(spender, amount);  // handles non-standard approve
```

### Address validation

Check zero addresses on every setter and initializer:

```solidity
if (token_ == address(0)) revert Contract_ZeroAddress();
```

### Reentrancy

CEI is the primary defense. Use `ReentrancyGuardUpgradeable` as a secondary layer on functions that interact with untrusted contracts.

---

## Gas Optimization

### `calldata` over `memory`

Use `calldata` for external function parameters that are not modified:

```solidity
function process(bytes calldata data) external { ... }      // good
function process(bytes memory data) external { ... }         // wastes gas copying
```

### Storage packing

Order state variables to minimize storage slots:

```solidity
// 1 slot (packed)
address public owner;    // 20 bytes
bool public paused;      // 1 byte
uint8 public decimals;   // 1 byte

// DON'T interleave with uint256 — wastes slots
```

### Short-circuit and early returns

Check the cheapest conditions first:

```solidity
if (amount == 0) revert ZeroAmount();         // cheap check first
if (balances[msg.sender] < amount) revert();  // storage read second
```

### Unchecked blocks

Use `unchecked` only when overflow is mathematically impossible:

```solidity
unchecked { i++; }  // loop counter — safe because bounded by array length
```

---

## Structs to Prevent Stack Too Deep

When a function has too many local variables, pack them into a struct:

```solidity
struct ClaimParams {
    address beneficiary;
    uint256 amount;
    bytes32 merkleRoot;
    bytes32[] proof;
    uint256 deadline;
}

function claim(ClaimParams calldata params) external { ... }
```

Also useful for return values and internal function parameters.

---

## Math & Rounding

For any `mulDiv` operation, always use OpenZeppelin's `Math.mulDiv`:

```solidity
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Round DOWN (default) — use when calculating user's share/claim
uint256 shares = Math.mulDiv(amount, totalShares, totalAssets);

// Round UP — use when calculating what user must pay/deposit
uint256 cost = Math.mulDiv(amount, totalShares, totalAssets, Math.Rounding.Ceil);
```

- **Round down** when giving value to the user (protects the protocol)
- **Round up** when taking value from the user (protects the protocol)
- Never use `a * b / c` directly — it can overflow the intermediate `a * b`

---

## View Functions for UI/UX

Expose view functions that aggregate state for frontend consumption. These save multiple RPC calls:

```solidity
struct UserInfo {
    uint256 balance;
    uint256 pendingRewards;
    uint256 stakedAmount;
    bool isWhitelisted;
}

function getUserInfo(address user) external view returns (UserInfo memory) {
    return UserInfo({
        balance: balanceOf(user),
        pendingRewards: _calculateRewards(user),
        stakedAmount: stakes[user],
        isWhitelisted: whitelist[user]
    });
}
```

- Return structs for complex data
- Name them clearly — the frontend team will read these
- Keep computation light — view functions still cost gas in `eth_call`

---

## Don't Duplicate Code

- Extract shared logic into `internal` or `private` functions
- Use inheritance for cross-contract shared behavior (e.g. `UUPSOwnable2Step`)
- Use libraries for stateless utility operations (e.g. `Create2Utils`)
- If two functions differ only in an access check, extract the core logic and have two entry points call it

```solidity
function setConfig(Config calldata config) external onlyAdmin {
    _setConfig(config);
}

function setConfigOnInit(Config calldata config) internal {
    _setConfig(config);  // reused during initialize()
}

function _setConfig(Config calldata config) private {
    // actual logic lives here once
}
```

---

## State Machine Patterns

For contracts with lifecycle stages (e.g. funding → active → closed):

```solidity
enum Status { Funding, Active, Closed }
Status public status;

modifier inStatus(Status expected) {
    if (status != expected) revert Contract_InvalidStatus(status, expected);
    _;
}

function activate() external onlyAdmin inStatus(Status.Funding) {
    status = Status.Active;
    emit StatusChanged(Status.Funding, Status.Active);
}
```

---

## Interface Design

- Define **all** external function signatures in the interface
- Define **custom errors** in the interface
- Define **events** in the interface (or in the contract if interface-less)
- The interface is the contract's API — it should be self-documenting with NatSpec

```solidity
interface IVault {
    error Vault_ZeroAmount();
    error Vault_InsufficientBalance(uint256 available, uint256 requested);

    event Deposited(address indexed user, uint256 amount);

    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getUserInfo(address user) external view returns (UserInfo memory);
}
```

---

## NatSpec Documentation

Full NatSpec conventions are in [natspec.md](natspec.md). Summary:

- `@title`, `@author`, `@notice` on every contract
- `@notice` + `@param` + `@return` on every `external`/`public` function
- `@dev` only when there's a non-obvious implementation detail
- `@custom:security-contact` on base contracts
- Document **why**, not what — the code already shows the what

---

## Dependencies

- **OpenZeppelin** (`@openzeppelin/contracts` + `@openzeppelin/contracts-upgradeable`) as the default dependency for standard patterns
- **Solady** (`vectorized/solady`) when gas optimization is critical and the OZ equivalent is too expensive
- Install with `forge install`, configure remappings in `foundry.toml`
- Pin dependency versions — never use floating branches in production

---

## Checklist Before Shipping

- [ ] All state-changing functions follow CEI
- [ ] Custom errors defined in interface, no `require` strings
- [ ] Events emitted for every state change with sufficient data
- [ ] Zero-address checks on all address parameters in setters and initializers
- [ ] `SafeERC20` used for all token transfers
- [ ] Owner = restrictive multisig (upgrades only), Admin = operational multisig
- [ ] Implementation contract initialized (prevent takeover)
- [ ] No `selfdestruct`, no `delegatecall` to arbitrary targets
- [ ] `calldata` used instead of `memory` where possible
- [ ] Storage variables packed efficiently
- [ ] `mulDiv` uses OZ Math with correct rounding direction
- [ ] View functions exposed for frontend aggregation
- [ ] NatSpec on all public/external functions and interfaces
- [ ] `forge test -vvv` passes with no warnings

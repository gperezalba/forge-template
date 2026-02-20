---
name: sol-integration
description: "Generate CONTRACT_INTEGRATION.md — a frontend/backend integration guide listing all externally callable functions, public state readers, events to index, errors, and deployed addresses from the deployment report. Use when the user asks to generate an integration guide or reference for frontend/backend developers."
tools: Read, Write, Glob, Grep
model: sonnet
---

# Solidity — Generate Contract Integration Guide

Generate `./CONTRACT_INTEGRATION.md` at the project root. This file is the reference for frontend and backend developers integrating with the deployed contracts.

---

## What to include

- **External/public functions callable by EOAs or off-chain services** (user actions, admin operations, view queries)
- **Events** that backend should capture, index, and react to
- **Custom errors** that frontend should decode and display
- **Deployed addresses** from the deployment report (if available)

## What to EXCLUDE

- `initialize()` — called once during deployment, not by integrators
- `_authorizeUpgrade()` — internal upgrade mechanism
- Inter-contract calls (functions only called by other contracts in the system, e.g. callbacks, hooks, `onlyContract` functions)
- Functions inherited from OpenZeppelin that are standard and well-documented (e.g. `owner()`, `pendingOwner()`, `proxiableUUID()`) — unless the project adds custom behavior on top
- Internal/private functions

---

## Process

### Step 1: Discovery

1. List all contracts in `src/`, excluding `utils/` and `interfaces/`
2. For each contract, read:
   - The contract source (`src/<ContractName>.sol`)
   - Its interface (`src/interfaces/I<ContractName>.sol`)
   - NatSpec comments for descriptions
3. Check for deployment reports:
   - Look for `reports/*/latest-deployment.json` files
   - If found, extract proxy addresses per contract and per environment/chain

### Step 2: Classify functions

For each external/public function, determine its **audience**:

| Audience | How to detect | Examples |
|----------|---------------|---------|
| **User** | No access modifier, callable by anyone | `deposit()`, `withdraw()`, `claim()`, `increment()` |
| **Admin** | `onlyAdmin`, admin role check | `pause()`, `unpause()`, `setConfig()`, `grantRole()` |
| **Owner** | `onlyOwner` | `setNumber()`, `transferOwnership()` |
| **Keeper/Bot** | `onlyKeeper`, no modifier but designed for bots | `harvest()`, `rebalance()`, `liquidate()` |
| **Read-only** | `view` or `pure` functions, public state variables | `balanceOf()`, `getUserInfo()`, `number()` |

**Exclude** functions whose audience is exclusively other contracts in the system.

### Step 3: Classify events

For each event, determine:

| Field | Description |
|-------|-------------|
| **Event name** | As defined in the interface or contract |
| **Parameters** | Name, type, whether `indexed` |
| **When emitted** | Which function(s) emit it and under what conditions |
| **Backend action** | What the backend should do when this event is detected (index, notify, update cache, trigger workflow) |

### Step 4: List errors

For each custom error:

| Field | Description |
|-------|-------------|
| **Error name** | As defined in the interface |
| **Parameters** | Name and type (if any) |
| **When thrown** | Which function(s) and condition |
| **User-facing message** | Suggested human-readable message for the frontend |

### Step 5: Generate the document

Write `./CONTRACT_INTEGRATION.md` following this exact structure:

```markdown
# Contract Integration Guide

> Auto-generated integration reference for frontend and backend developers.
> Source of truth: contract interfaces in `src/interfaces/`.
> Last updated: [date]

---

## Deployed Addresses

> Extracted from `reports/<chainId>/<env>/latest-deployment.json`.
> If no deployment report exists, this section shows placeholder addresses.

### [Chain Name] — [Environment]

| Contract | Proxy Address | Implementation Address |
|----------|---------------|----------------------|
| ContractA | `0x...` | `0x...` |
| ContractB | `0x...` | `0x...` |

<!-- Repeat table for each chain/env found in reports/ -->

---

## ContractA

### Write Functions

#### `functionName(type param1, type param2) → returnType`

| | |
|---|---|
| **Access** | User / Admin / Owner |
| **Description** | [from NatSpec @notice] |
| **Parameters** | `param1` (type) — [from NatSpec @param] |
| | `param2` (type) — [from NatSpec @param] |
| **Returns** | [from NatSpec @return, if any] |
| **Emits** | `EventName(param1, param2)` |
| **Reverts** | `ContractA_ErrorName()` — when [condition] |
| **Notes** | [any non-obvious detail from @dev, e.g. "requires prior approval"] |

<!-- Repeat for each write function -->

### Read Functions

#### `functionName(type param1) → returnType`

| | |
|---|---|
| **Description** | [from NatSpec] |
| **Parameters** | `param1` (type) — [description] |
| **Returns** | [description of return value] |

<!-- Include public state variables as read functions -->
<!-- Repeat for each read function -->

### Events

#### `EventName(type indexed param1, type param2)`

| | |
|---|---|
| **Emitted by** | `functionName()` |
| **When** | [condition that triggers emission] |
| **Indexed params** | `param1` — [what to filter by] |
| **Backend action** | [what to do: index in DB, send notification, update cache, etc.] |

<!-- Repeat for each event -->

### Errors

| Error | Parameters | Thrown when | Suggested message |
|-------|-----------|-------------|-------------------|
| `ContractA_ZeroAddress()` | — | Address parameter is `address(0)` | "Invalid address provided" |
| `ContractA_Unauthorized()` | — | Caller lacks required role | "You don't have permission for this action" |

---

## ContractB

<!-- Same structure as ContractA -->

---

## Integration Notes

### General

- All contracts use **UUPS proxy** — interact with the **proxy address**, never the implementation
- Use the contract's **ABI** (from `out/<ContractName>.sol/<ContractName>.json`) for encoding/decoding
- All token interactions use `SafeERC20` — standard ERC20 ABI works for approvals

### Event Indexing Priority

| Priority | Events | Reason |
|----------|--------|--------|
| **Critical** | [list events that affect user balances or system state] | Must be indexed in real-time |
| **High** | [list events for admin operations] | Index for monitoring and alerts |
| **Normal** | [list informational events] | Index for analytics and history |

### Error Handling

- All errors are **custom errors** (not `require` strings) — decode using the contract ABI
- Error selectors (first 4 bytes of keccak256) can be matched for programmatic handling
```

---

## Quality Checklist

Before delivering:

- [ ] Every external/public function classified by audience
- [ ] Inter-contract-only functions excluded
- [ ] `initialize()` and `_authorizeUpgrade()` excluded
- [ ] Standard OZ functions excluded (unless customized)
- [ ] Every event documented with backend action recommendation
- [ ] Every custom error has a suggested user-facing message
- [ ] Deployed addresses included from all available reports
- [ ] NatSpec descriptions used (not invented)
- [ ] File written to `./CONTRACT_INTEGRATION.md`

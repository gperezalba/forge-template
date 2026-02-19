---
name: sol-audit
description: "[Solidity] Security audit for smart contracts. Runs Slither, performs manual vulnerability analysis across 12 categories (reentrancy, access control, oracle, flash loans, MEV, tokens...), checks template-specific patterns, and generates a findings report."
argument-hint: "<ContractName|path> [--full]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Solidity Security Audit

Perform a security audit on Solidity smart contracts.

**Input**: `$ARGUMENTS`
- `ContractName` — audit a single contract (`src/ContractName.sol`)
- `src/path/to/Contract.sol` — audit a specific file
- `--full` flag — audit ALL contracts in `src/` (excludes `utils/`, `interfaces/`)

**Prerequisite**: Slither must be installed (`pip install slither-analyzer`).

---

## Phase 1: Discovery & Scope

1. Determine scope from `$ARGUMENTS`:
   - Single contract: read the contract + its interface + inherited contracts
   - `--full`: list all contracts in `src/`, excluding `interfaces/` and `utils/`
2. For each contract in scope, read:
   - The contract source
   - Its interface (`src/interfaces/I<ContractName>.sol`)
   - Parent contracts it inherits from
   - Any library it uses
3. Build a mental model:
   - List all external/public functions with their access modifiers
   - Map state variables and who can write to them
   - Identify external calls (token transfers, cross-contract calls, low-level calls)
   - Identify trust boundaries (owner vs admin vs anyone)
   - Map the state machine (if lifecycle-based)

**Output**: Present the scope summary to the user before continuing:

> **Audit scope**: [N] contracts, [M] external functions, [K] external calls identified.
> Key actors: owner (multisig), admin, users.
> External dependencies: [list tokens, oracles, etc.]

---

## Phase 2: Static Analysis (Slither)

Run Slither on the project and analyze results:

```bash
slither . --exclude-dependencies --json slither-report.json 2>&1
```

Then analyze the output:

1. **Parse findings by severity**: High, Medium, Low, Informational
2. **Filter false positives**: Common false positives in this template:
   - `reentrancy-benign` on event emissions after state changes (usually fine if CEI is followed)
   - `uninitialized-state` on proxy patterns (implementation variables set in `initialize`)
   - `shadowing-local` on constructor params with trailing underscore (intentional pattern)
   - `assembly` warnings on OZ internal code (not our code)
3. **Present genuine findings** with file:line references and fix recommendations
4. **Run specialized checks** if applicable:

```bash
# If contract is upgradeable
slither-check-upgradeability . ContractName --proxy-filename src/ContractName.sol

# If contract is/integrates ERC20
slither-check-erc . ContractName --erc erc20
```

---

## Phase 3: Manual Vulnerability Analysis

For each contract in scope, check ALL categories below. Do not skip any — verify with code search before declaring "not applicable".

### 3.1 Reentrancy

Search for external calls followed by state changes:

```
Pattern: .transfer(, .call(, .safeTransfer(, .safeTransferFrom(,
         onERC721Received, tokensReceived, any callback hook
```

For each external call found:
- Is state updated BEFORE the call? (CEI compliant)
- Is `ReentrancyGuard` used as additional protection?
- Can a cross-function reentrancy occur? (different function, shared state)
- Can a read-only reentrancy occur? (view function returns stale data during callback)

### 3.2 Access Control

For every external/public state-changing function:
- Is there an access modifier? (`onlyOwner`, `onlyAdmin`, role check)
- If public without restriction — is this intentional?
- Is `initialize()` protected by `initializer` modifier?
- Is `_authorizeUpgrade()` restricted to `onlyOwner`?
- Check for `tx.origin` usage (only legitimate in Deployer constructor)

### 3.3 Input Validation

For every function parameter:
- Are address parameters checked against `address(0)`?
- Are numeric parameters bounded? (zero amount, max value, overflow on cast)
- Are array lengths validated when multiple arrays expected to match?
- Are bytes/string parameters validated when decoded?

### 3.4 Arithmetic & Precision

Search for:
- `a * b / c` patterns — should use `Math.mulDiv`
- `unchecked` blocks — verify overflow is mathematically impossible
- Decimal handling between tokens with different decimals (6 vs 18)
- Division that can produce zero (rounding to zero on small values)
- Rounding direction — protocol should always round in its own favor

### 3.5 Storage & Proxy Safety

- Is the implementation contract initialized on deploy? (prevents takeover)
- Is storage layout compatible with previous version? (if upgrade)
- Are there any `selfdestruct` or `delegatecall` to arbitrary targets?
- Is there a storage gap in base contracts? (if used as inheritable base)
- Do new state variables go at the END of the storage layout?

### 3.6 External Calls & Token Safety

- Is `SafeERC20` used for ALL token transfers?
- Are return values from external calls checked?
- Is there any push pattern in loops? (should be pull)
- Are callbacks (ERC-721 `safeTransfer`, ERC-777 hooks) handled safely?
- Is gas limited on untrusted calls?

### 3.7 Events & Monitoring

- Does every state change emit an event?
- Do events include sufficient data for off-chain reconstruction?
- Are critical events indexed for filtering?
- Is there an event for ownership transfer, pausing, upgrading?

### 3.8 Oracle Security (if applicable)

Search for Chainlink or any price feed usage:
- Is staleness checked? (`block.timestamp - updatedAt > threshold`)
- Is the price validated? (`price > 0`)
- Is `roundId` / `answeredInRound` checked?
- On L2: is sequencer uptime checked?
- Is spot AMM price used as oracle? (vulnerable to flash loan manipulation)

### 3.9 Flash Loan Risks (if applicable)

- Can any function be exploited within a single transaction via flash-borrowed funds?
- Are prices derived from spot balances? (manipulable)
- Can governance actions be executed with flash-borrowed voting power?
- Does the protocol check `balanceOf` before and after for fee-on-transfer tokens?

### 3.10 MEV & Front-running (if applicable)

- Are there swap-like operations without slippage protection?
- Are deadline parameters enforced for time-sensitive operations?
- Are there on-chain secrets that should use commit-reveal?
- Can transaction ordering affect the outcome of any function?

### 3.11 Token Integration (if applicable)

If the contract interacts with external tokens, check ALL weird token patterns:

| Pattern | Check |
|---------|-------|
| Missing return value | Using `SafeERC20`? |
| Fee on transfer | Balance diff check? |
| Rebasing | Shares-based accounting? |
| Blocklist/pausable | Graceful failure handling? |
| Non-standard decimals | Decimal normalization? |
| Approval race | Using `forceApprove`? |
| ERC-777 hooks | Reentrancy protection? |

**Tip**: If token integration is complex, recommend running the Trail of Bits `token-integration-analyzer` skill for a deep analysis.

### 3.12 Logic & State Machine

- Are state transitions validated? (can't skip states)
- Are one-time operations guarded? (double claim, double deploy)
- Are deadline/timestamp comparisons correct? (`<` vs `<=`)
- Are there locked funds scenarios? (ETH sent with no withdrawal)
- Are return values from internal functions used?

---

## Phase 4: Template-Specific Checks

These are specific to the forge-template patterns:

### UUPS Proxy Pattern

- [ ] `UUPSOwnable2Step` inherited correctly
- [ ] `initialize()` calls all parent initializers in order: `__Ownable_init`, `__Ownable2Step_init`, `__UUPSUpgradeable_init`, `__UUPSOwnable2Step_init`
- [ ] `initialize()` validates owner != address(0)
- [ ] `_authorizeUpgrade` is `onlyOwner` and `view`
- [ ] Implementation initialized in deployment scripts (Deployer + SingleDeploy)
- [ ] No constructor with state (only immutables allowed)

### Deployer Contract

- [ ] `AUTHORIZED` set to `tx.origin` in constructor (intended for CREATE2)
- [ ] `_deployed` guard prevents re-execution
- [ ] All proxies initialized with correct params
- [ ] Event emitted with all deployed addresses

### Access Control Model

- [ ] Owner = restrictive multisig (upgrades + ownership transfer ONLY)
- [ ] Admin = operational multisig (pause, config, roles) — different address from owner
- [ ] No function mixes upgrade authority with daily operations

---

## Phase 5: Report Generation

Generate a markdown report file at `reports/audit/<ContractName>-audit.md` (or `reports/audit/full-audit.md` for `--full`).

### Report Structure

```markdown
# Security Audit Report

**Project**: [name]
**Scope**: [contracts audited]
**Date**: [date]
**Auditor**: Claude (AI-assisted)

---

## Executive Summary

- **Critical**: [N] findings
- **High**: [N] findings
- **Medium**: [N] findings
- **Low**: [N] findings
- **Informational**: [N] findings

**Overall assessment**: [1-2 sentences]

---

## Findings

### [C-01] Title
**Severity**: Critical
**Contract**: ContractName.sol
**Function**: functionName()
**Line**: [N]

**Description**: [What the issue is]

**Impact**: [What can go wrong, who is affected]

**Proof of Concept**:
```solidity
// Attack scenario or vulnerable code path
```

**Recommendation**:
```solidity
// Suggested fix
```

---

### [H-01] Title
...

---

## Static Analysis Results

### Slither
- **High**: [findings or "Clean"]
- **Medium**: [findings or "Clean"]
- **Low**: [findings or "Clean"]
- **Triaged false positives**: [list]

### Upgradeability Check
- [results or "N/A"]

### ERC Conformity
- [results or "N/A"]

---

## Template Compliance

| Check | Status |
|-------|--------|
| UUPS pattern correct | |
| Implementation initialized | |
| _authorizeUpgrade restricted | |
| Owner/Admin separation | |
| CEI followed | |
| SafeERC20 used | |
| Custom errors (no require strings) | |
| Events on all state changes | |
| Zero address validation | |
| Math.mulDiv used | |

---

## Recommendations

### Immediate (Critical/High)
1. ...

### Before Deploy (Medium)
1. ...

### Nice to Have (Low/Info)
1. ...

---

## Complementary Tools

For deeper analysis, consider running:
- `audit-context-building` — ultra-granular line-by-line context building
- `token-integration-analyzer` — if integrating external tokens
- `code-maturity-assessor` — overall project maturity scorecard
- `secure-workflow-guide` — Slither visual diagrams and property documentation
```

---

## Severity Classification

| Severity | Criteria |
|----------|----------|
| **Critical** | Direct loss of funds, permanent DoS, unauthorized upgrade |
| **High** | Conditional loss of funds, access control bypass, state corruption |
| **Medium** | Unexpected behavior under edge conditions, griefing, economic inefficiency |
| **Low** | Best practice violations, code quality, gas optimization |
| **Informational** | Suggestions, style, documentation gaps |

---

## Quality Checklist

Before delivering the report:

- [ ] Slither executed and results analyzed
- [ ] All 12 vulnerability categories checked with code evidence
- [ ] All template-specific checks verified
- [ ] Every finding has: severity, contract, function, line, description, impact, recommendation
- [ ] No category skipped without explicit verification
- [ ] Report file generated at `reports/audit/`
- [ ] False positives documented with reasoning

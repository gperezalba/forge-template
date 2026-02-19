# Security Audit Reference

Vulnerability taxonomy, security patterns, and audit methodology for Solidity smart contracts. Covers language-level and DeFi-specific risks.

---

## Vulnerability Taxonomy

### 1. Reentrancy

External calls transfer control to untrusted code that can re-enter the calling contract before state is updated.

| Variant | Description |
|---------|-------------|
| **Single-function** | Same function re-entered via external call |
| **Cross-function** | Different function in same contract re-entered, shares state |
| **Cross-contract** | Callback re-enters a different contract that shares state |
| **Read-only** | View function returns stale data during reentrancy (ERC-4626, Curve) |

**Defense**: CEI pattern (Checks-Effects-Interactions). Use `ReentrancyGuardUpgradeable` as secondary layer.

**Pattern to find**: Any external call (`transfer`, `call`, `safeTransfer`, hooks like `onERC721Received`) followed by state updates.

---

### 2. Access Control

| Issue | Description |
|-------|-------------|
| **Missing modifier** | State-changing function lacks access restriction |
| **Wrong role** | Function uses `onlyOwner` when it should be `onlyAdmin` (or vice versa) |
| **Unprotected initializer** | `initialize()` callable by anyone on uninitialized proxy or implementation |
| **`_authorizeUpgrade` unprotected** | UUPS upgrade callable by non-owner |
| **`tx.origin` authentication** | Phishable — never use for auth (legitimate in Deployer constructor for CREATE2) |
| **Default role** | `AccessControl` default admin role assigned to deployer but never transferred |

**Defense**: Two-tier model (Owner for upgrades, Admin for operations). `Ownable2StepUpgradeable` prevents accidental ownership transfer.

---

### 3. Input Validation

| Issue | Description |
|-------|-------------|
| **Zero address** | Setting owner, token, or critical address to `address(0)` |
| **Zero amount** | Transferring or depositing zero, can break accounting |
| **Array length mismatch** | Two arrays expected to match length but not validated |
| **Overflow in calldata** | Unchecked `uint256` passed to narrower type without bounds check |
| **Empty bytes** | `bytes calldata` that's empty passed to decode/parse functions |

**Defense**: Validate all external inputs at the boundary. Use custom errors.

---

### 4. Arithmetic & Precision

| Issue | Description |
|-------|-------------|
| **Intermediate overflow** | `a * b / c` overflows before division (use `Math.mulDiv`) |
| **Division before multiplication** | `(a / b) * c` loses precision — always multiply first |
| **Rounding direction** | Protocol should always round in its own favor |
| **Phantom overflow in unchecked** | `unchecked` block around arithmetic that CAN overflow |
| **Decimal mismatch** | Mixing 18-decimal and 6-decimal tokens without normalization |
| **Downcasting** | `uint256` cast to `uint128` without overflow check |

**Defense**: Use OZ `Math.mulDiv` with explicit rounding. Never use `unchecked` unless overflow is mathematically impossible.

---

### 5. Storage & Proxy

| Issue | Description |
|-------|-------------|
| **Uninitialized implementation** | Anyone can call `initialize()` on the implementation contract and `selfdestruct` (pre-Cancun) or manipulate state |
| **Storage collision** | Upgrade changes storage layout — new variable inserted before existing ones |
| **Storage gap missing** | Base contract without `__gap` prevents child contracts from adding storage safely |
| **Function selector clash** | Proxy function selector collides with implementation function |
| **`delegatecall` to untrusted target** | Allows arbitrary code execution in proxy context |
| **`selfdestruct` in implementation** | Destroys implementation, bricking all proxies (pre-Cancun) |

**Defense**: Always initialize implementations. Use `forge inspect` to compare storage layouts before upgrades. Never add `selfdestruct` or `delegatecall` to arbitrary targets.

---

### 6. External Calls

| Issue | Description |
|-------|-------------|
| **Unchecked return value** | `token.transfer()` returns `false` silently (USDT, BNB) — use SafeERC20 |
| **Gas griefing** | Forwarding all gas to untrusted call, allowing griefing via returnbomb |
| **Denial of Service** | External call in loop — one revert blocks entire batch |
| **Unexpected callback** | ERC-721 `safeTransferFrom`, ERC-777 hooks trigger callbacks to receiver |
| **Phantom function** | Calling a function that doesn't exist — call succeeds with empty returndata on EOA |

**Defense**: `SafeERC20` for all token transfers. Pull over push for payments. Limit gas on untrusted calls.

---

### 7. DeFi-Specific: Oracle Manipulation

| Issue | Description |
|-------|-------------|
| **Spot price as oracle** | Using AMM reserve ratio (`getReserves`) as price — easily manipulated via flash loan |
| **TWAP manipulation** | Low-liquidity TWAP oracle manipulated over multiple blocks |
| **Stale price** | Chainlink price feed not checked for freshness (`updatedAt` too old) |
| **Incomplete Chainlink check** | Not checking `roundId`, `answeredInRound`, or `price > 0` |
| **L2 sequencer downtime** | Chainlink on L2 without sequencer uptime feed check |

**Defense**: Use Chainlink with full validation (staleness, sequencer, roundId). Never use spot AMM prices.

```solidity
(, int256 price,, uint256 updatedAt,) = feed.latestRoundData();
if (price <= 0) revert Oracle_InvalidPrice();
if (block.timestamp - updatedAt > STALENESS_THRESHOLD) revert Oracle_StalePrice();
```

---

### 8. DeFi-Specific: Flash Loans

| Issue | Description |
|-------|-------------|
| **Price manipulation** | Flash loan to move AMM price → interact with protocol at manipulated price → repay |
| **Governance attack** | Flash loan tokens → vote → repay in same tx |
| **Collateral manipulation** | Flash loan to inflate collateral value, borrow, withdraw, repay |
| **Flash minting** | Token allows flash minting — temporary supply inflation |

**Defense**: Don't rely on spot balances or prices within a single transaction. Use TWAPs or external oracles. Check `balanceOf` before and after operations for fee-on-transfer tokens.

---

### 9. DeFi-Specific: MEV & Front-running

| Issue | Description |
|-------|-------------|
| **Sandwich attack** | Attacker front-runs large swap to move price, then back-runs to profit |
| **Slippage exploitation** | User sets 100% slippage tolerance — MEV bot extracts maximum value |
| **Liquidation MEV** | Bots front-run liquidation calls for profit |
| **Commit-reveal needed** | On-chain secret revealed before use (auctions, games) |
| **Transaction ordering dependence** | Function outcome depends on execution order |

**Defense**: Enforce maximum slippage parameters. Use commit-reveal for secrets. Use deadline parameters for time-sensitive operations.

---

### 10. DeFi-Specific: Token Integration Risks

| Pattern | Affected tokens | Risk |
|---------|----------------|------|
| **Missing return value** | USDT, BNB, OMG | `transfer` returns `void`, not `bool` |
| **Fee on transfer** | STA, PAXG, USDT (configurable) | Received amount < sent amount |
| **Rebasing** | stETH, AMPL, OHM | Balance changes without transfers |
| **Blocklist** | USDC, USDT | Transfers revert for blacklisted addresses |
| **Pausable** | BNB, ZIL | All transfers revert when paused |
| **Upgradeable** | USDC, USDT | Token behavior can change post-deployment |
| **Multiple addresses** | Synthetix proxies | Same token reachable via different addresses |
| **Non-standard decimals** | USDC (6), WBTC (8), GeminiUSD (2) | Arithmetic assumes 18 decimals |
| **Approval race condition** | USDT (requires 0 approval first) | `approve(x)` reverts if current allowance != 0 |
| **Large approval revert** | UNI, COMP | `approve(amount)` reverts if amount >= 2^96 |
| **ERC-777 hooks** | imBTC | `tokensReceived` hook enables reentrancy |

**Defense**: Always use `SafeERC20`. Use `forceApprove` instead of `approve`. Verify received amounts with balance diff for fee-on-transfer support.

---

### 11. Logic & State Machine Bugs

| Issue | Description |
|-------|-------------|
| **State transition skip** | Jumping from `Funding` to `Closed` without going through `Active` |
| **Deadline bypass** | Using `<=` instead of `<` for block.timestamp checks |
| **Off-by-one** | Array length vs index, boundary conditions |
| **Double spend / double claim** | Missing nonce, missing "already claimed" flag |
| **Locked funds** | ETH or tokens sent to contract with no withdrawal mechanism |
| **Unused return value** | Internal function returns important value that caller ignores |

**Defense**: State machines with explicit transition guards. Mapping flags for one-time operations.

---

### 12. Gas & DoS

| Issue | Description |
|-------|-------------|
| **Unbounded loop** | Iterating over unbounded array — gas exceeds block limit |
| **External call in loop** | One failing call blocks entire batch |
| **Block gas limit DoS** | Attacker fills array to make function uncallable |
| **Storage write in loop** | Each SSTORE costs 20k+ gas |

**Defense**: Pull over push. Paginate operations. Bound array sizes.

---

## Security Patterns for This Template

### UUPS Proxy Checklist

- [ ] Implementation initialized on deploy (prevents takeover)
- [ ] `_authorizeUpgrade` restricted to `onlyOwner`
- [ ] Owner is a restrictive multisig (high threshold)
- [ ] No `selfdestruct` in implementation
- [ ] No `delegatecall` to arbitrary targets
- [ ] Storage layout validated before upgrade (`forge inspect`)
- [ ] `Ownable2StepUpgradeable` used (prevents accidental transfer)

### CREATE2 Checklist

- [ ] Salt includes version to prevent address reuse across versions
- [ ] Deployer contract has one-shot guard (`_deployed` flag)
- [ ] CREATE2 factory address verified on target chain

### Access Control Checklist

- [ ] Owner = restrictive multisig (upgrades only)
- [ ] Admin = operational multisig (pause, config) — separate from owner
- [ ] All external state-changing functions have access control or are intentionally public
- [ ] `initialize()` validates all address parameters against zero address

---

## Pre-Deploy Security Checklist

| Category | Check |
|----------|-------|
| **Static analysis** | `slither . --exclude-dependencies` clean or triaged |
| **Tests** | `npm run test:local` passes, coverage > 90% for critical paths |
| **CEI** | Every state-changing function follows Checks-Effects-Interactions |
| **Custom errors** | No `require` with string messages — all custom errors |
| **Events** | Every state change emits an event with sufficient data |
| **Zero address** | All setters and initializers check `address(0)` |
| **SafeERC20** | All token transfers use `safeTransfer` / `safeTransferFrom` |
| **Math** | All `a * b / c` use `Math.mulDiv` with correct rounding |
| **Proxy** | Implementation initialized, `_authorizeUpgrade` is `onlyOwner` |
| **Storage** | Layout compatible with previous version (if upgrade) |
| **Calldata** | External params use `calldata` over `memory` where possible |
| **Formatting** | `forge fmt` applied |
| **Linting** | `npm run solhint:check` passes |

---

## Trail of Bits Skills Reference

These skills from `~/.claude/skills/trailofbits/` complement the audit process:

| Skill | When to use | Invocation |
|-------|-------------|------------|
| **audit-context-building** | Deep line-by-line context building before vulnerability hunting | Use before `/sol-audit` for complex codebases |
| **code-maturity-assessor** | Systematic 9-category maturity scorecard | Overall project assessment |
| **token-integration-analyzer** | Analyzing 24+ weird ERC20 patterns and integration safety | When the project integrates external tokens |
| **secure-workflow-guide** | 5-step security workflow with Slither diagrams and property documentation | Regular security check during development |
| **differential-review** | Security-focused PR review with blast radius analysis | Reviewing code changes and PRs |
| **audit-prep-assistant** | Pre-audit preparation: static analysis, coverage, documentation | 1-2 weeks before external audit |

---

## Tools

| Tool | Purpose | Command |
|------|---------|---------|
| **Slither** | Static analysis (70+ detectors) | `slither . --exclude-dependencies` |
| **slither-check-erc** | ERC conformity validation | `slither-check-erc . ContractName --erc erc20` |
| **slither-check-upgradeability** | Proxy/upgrade safety checks | `slither-check-upgradeability . ContractName` |
| **Echidna** | Property-based fuzzing | `echidna . --contract InvariantTest` |
| **Foundry invariant tests** | Stateful fuzz testing | `forge test --match-contract Invariant` |
| **forge inspect** | Storage layout inspection | `forge inspect src/Contract.sol:Contract storage --pretty` |

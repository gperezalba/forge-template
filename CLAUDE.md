# forge-template

Foundry project template with UUPS upgradeable contracts, CREATE2 deterministic deployments, and BTT testing.

## Commands

- **Build**: `npm run build`
- **Test (all)**: `npm run test`
- **Test (local only)**: `npm run test:local`
- **Test (fork only)**: `npm run test:fork`
- **Lint**: `npm run solhint:check`
- **Lint fix**: `npm run solhint:fix`
- **Coverage**: `npm run coverage`
- **Docs**: `npm run doc`
- **Format**: `forge fmt`

Run `forge test -vvv` after every change to see debug traces.

## Code Style

- **Solidity version**: 0.8.24 (explicit in all files)
- **Naming**: See `docs/solidity/naming-conventions.md` for the full reference
- **NatSpec**: Required on all public/external elements. See `docs/solidity/natspec.md`
- **Linting**: `.solhint.json` enforces private vars underscore prefix, camelCase params/modifiers, double quotes
- **Formatting**: `forge fmt` when prompted

## Architecture

- All contracts use **UUPS proxy** pattern via `UUPSOwnable2Step` base
- **Owner** = restrictive multisig (upgrades only). **Admin** = operational multisig (pause, config)
- Deployments use **CREATE2** via SafeSingletonFactory for deterministic addresses
- Deployment report at `reports/<chainId>/<env>/latest-deployment.json` is the source of truth for all scripts

IMPORTANT: Read `docs/solidity/` before writing contracts, tests, or scripts. Each doc covers a specific area in detail.

## Workflow

- **New contract**: Write contract + interface → add to Deployer → write `.tree` specs → scaffold → implement tests
- **New test**: Write `.tree` → `bulloak scaffold -w -s 0.8.24 <path>` → implement (don't modify scaffold structure)
- **Deploy**: `npm run deploy:<chain>:<env>` → generates report
- **Single deploy**: `npm run deploy:<contract>:impl|proxy:<chain>:<env>`
- **Workflow scripts**: Testnet only — admin actions via private key. Production uses multisig.

## Gotchas

<!-- Update this section when you learn something the hard way. Keep rules concise and absolute. -->

- ALWAYS use `SafeERC20` for token transfers — NEVER call `transfer`/`transferFrom` directly
- ALWAYS use `abi.encodeWithSelector` for custom errors with params in `vm.expectRevert`
- ALWAYS use `calldata` over `memory` for external function parameters that aren't modified
- ALWAYS use `Math.mulDiv` from OZ for multiplication-then-division — NEVER `a * b / c` (intermediate overflow)
- ALWAYS initialize implementation contracts on deploy — prevents takeover via uninitialized impl
- ALWAYS check zero addresses in setters and initializers
- NEVER use `require` with string messages — use custom errors (`ContractName_ErrorDescription`)
- NEVER use constructors for state in upgradeable contracts — use `initialize()` with `initializer` modifier
- NEVER update state after external calls — follow Checks-Effects-Interactions
- NEVER use `selfdestruct` or `delegatecall` to arbitrary targets in implementations
- NEVER push payments in loops — use pull pattern
- `bulloak scaffold` generates function names from `.tree` nodes — if names collide, make tree node text more specific
- `bulloak check` validates that `.t.sol` matches `.tree` spec — run it after modifying either file
- Fork tests MUST have `testFork` in the function name — otherwise `--no-match-test testFork` excludes them silently
- `npm run test:local` excludes fork tests, `npm run test:fork` runs only fork tests — use `npm run test` for both

## Self-Improvement

After every significant correction, update this file:

> "Update CLAUDE.md so you don't make that mistake again."

Add learned rules to the **Gotchas** section above. Keep rules:

- Concise (one line each)
- Absolute directives (ALWAYS/NEVER)
- Concrete with actual code or commands when possible

## References

- **[docs/INDEX.md](docs/INDEX.md)** — Full documentation index
- **[docs/solidity/project-structure.md](docs/solidity/project-structure.md)** — Directory layout and flows
- **[docs/solidity/naming-conventions.md](docs/solidity/naming-conventions.md)** — Naming rules at every level
- **[docs/solidity/contracts-implementation.md](docs/solidity/contracts-implementation.md)** — Smart contract best practices
- **[docs/solidity/natspec.md](docs/solidity/natspec.md)** — NatSpec documentation rules
- **[docs/solidity/deployment-flow.md](docs/solidity/deployment-flow.md)** — Deployment, single deploy, and upgrade flows
- **[docs/solidity/script-workflows.md](docs/solidity/script-workflows.md)** — Testnet operational scripts
- **[docs/solidity/btt-tests.md](docs/solidity/btt-tests.md)** — BTT tree spec format and bulloak scaffold
- **[docs/solidity/test-implementation.md](docs/solidity/test-implementation.md)** — Test types, patterns, and inheritance

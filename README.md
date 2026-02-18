# <h1 align="center"> Foundry Template (gperezalba style) </h1>

**Template repository for getting started quickly with Foundry in one project**

![Github Actions](https://github.com/gperezalba/forge-template/workflows/test/badge.svg)

### Getting Started

This project uses [Foundry](https://getfoundry.sh). See the [book](https://book.getfoundry.sh/getting-started/installation.html) for instructions on how to install and use Foundry.

```bash
forge install
forge test
```

Use this template to create a new project:

```bash
forge init --template https://github.com/gperezalba/forge-template dir_name
git remote set-url origin https://github.com/org/project-name.git
```

### Build & Test

```bash
npm run build
npm run test
npm run coverage
```

### Linting

```bash
npm run solhint:check
npm run solhint:fix
```

### Documentation

```bash
npm run doc
npm run doc-serve
```

### Deployment

Create a `.env` file with the required variables:

```
PRIVATE_KEY=
RPC_SEPOLIA=
RPC_POLYGON=
ETHERSCAN_API_KEY=
```

#### Full deployment (implementations + proxies)

Deploys all implementations via CREATE2, a Deployer contract, and all proxies in a single atomic transaction.

```bash
npm run deploy:sepolia:dev
npm run deploy:sepolia:int
npm run deploy:sepolia:sta
npm run deploy:polygon
```

#### Single deployment - Implementation only

Deploys a new implementation via CREATE2. Useful for preparing an upgrade.

```bash
npm run deploy:counter:impl:sepolia:dev
npm run deploy:counter:impl:sepolia:int
npm run deploy:counter:impl:sepolia:sta
npm run deploy:counter:impl:polygon
```

#### Single deployment - Implementation + Proxy

Deploys a new implementation and a new ERC1967 proxy pointing to it.

```bash
npm run deploy:counter:proxy:sepolia:dev
npm run deploy:counter:proxy:sepolia:int
npm run deploy:counter:proxy:sepolia:sta
npm run deploy:counter:proxy:polygon
```

### Workflows

```bash
npm run counter:setNumber:sepolia:dev
npm run counter:setNumber:sepolia:int
npm run counter:setNumber:sepolia:sta
```

### Notes

Whenever you install new libraries using Foundry, make sure to update your `remappings.txt` file by running `forge remappings > remappings.txt`.

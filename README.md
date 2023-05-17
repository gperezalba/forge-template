# <h1 align="center"> Foundry Template (gperezalba style) </h1>

**Template repository for getting started quickly with Foundry in one project**

![Github Actions](https://github.com/gperezalba/forge-template/workflows/test/badge.svg)

### Getting Started

This project uses [Foundry](https://getfoundry.sh). See the [book](https://book.getfoundry.sh/getting-started/installation.html) for instructions on how to install and use Foundry.

 * Use Foundry: 
```bash
forge install
forge test
```

### Features

 * Compile contracts:
```bash
npm run build
```

 * Run tests:
```bash
npm run test
```

 * Run and serve coverage:
```bash
npm run coverage
```

 * Generate and serve docs (http://localhost:4000):
```bash
npm run doc
npm run doc-serve
```

 * Install libraries with Foundry which work with Hardhat.
```bash
forge install rari-capital/solmate # Already in this repo, just an example
```

 * Use this template to create a new project
```bash
forge init --template https://github.com/gperezalba/forge-template dir_name
git remote set-url origin https://github.com/org/project-name.git
```

### Notes

Whenever you install new libraries using Foundry, make sure to update your `remappings.txt` file by running `forge remappings > remappings.txt`. This is required because we use `hardhat-preprocessor` and the `remappings.txt` file to allow Hardhat to resolve libraries you install with Foundry.
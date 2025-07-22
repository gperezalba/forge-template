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

### Automated Testing Workflow

This template supports an automated approach to generate comprehensive tests using BTT (Branching Tree Technique). Follow these steps:

#### Step 1: Generate BTT Tree Files

Use the following prompt with an AI assistant to automatically generate `.tree` files for all your contracts:

```
Analiza el contrato [ContractName] y crea los archivos .tree para todas sus funciones públicas/externas usando BTT. Organiza los trees por función considerando todos los caminos de ejecución posibles. Crea los archivos dentro de la carpeta tree/, crea subcarpetas para cada contrato y luego archivos para cada función.

IMPORTANTE: Los archivos .tree deben ser compatibles con bulloak:
- NO usar paréntesis, corchetes o caracteres especiales en los identificadores
- NO anidar múltiples "it should" statements
- Usar solo lenguaje natural simple
- Evitar números y símbolos matemáticos en los nombres
- CADA identificador "when"/"given" debe ser ÚNICO en todo el archivo
- Si hay condiciones similares en diferentes ramas, agregar contexto específico
```

**Example output structure:**
```
test/tree/ContractName/
├── function1.tree
├── function2.tree
└── function3.tree
```

Each `.tree` file maps out all possible execution paths for a function, considering:
- Contract state conditions (`given`)
- Function parameters (`when`) 
- Expected outcomes (`it should`)

#### Step 2: Generate Test Scaffolds

Once you have your `.tree` files, use bulloak to automatically generate test scaffolds:

```bash
bulloak scaffold -S -w test/tree/**/*.tree
```

This command will:
- Generate `.t.sol` files for each `.tree` file
- Create test functions following BTT naming conventions  
- Generate modifiers for `given` conditions
- Add commented expectations for each `it should` statement
- Use `vm.skip(true)` placeholders for implementation

**Example generated structure:**
```solidity
contract initializetree is Test {
    modifier givenTheContractIsNotInitialized() { _; }
    
    function test_WhenOwner_IsTheZeroAddressForFirstInitialization() 
        external givenTheContractIsNotInitialized 
    {
        // it should revert with Counter_ZeroAddress
        vm.skip(true);
    }
}
```

#### Next Steps (Coming Soon)

- **Step 3**: Auto-implement test modifiers and actual test logic
- **Step 4**: Integration with CI/CD pipeline

### Notes

Whenever you install new libraries using Foundry, make sure to update your `remappings.txt` file by running `forge remappings > remappings.txt`. This is required because we use `hardhat-preprocessor` and the `remappings.txt` file to allow Hardhat to resolve libraries you install with Foundry.
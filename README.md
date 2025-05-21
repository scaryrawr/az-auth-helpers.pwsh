# Azure Authentication Helpers for PowerShell

A PowerShell module providing utility functions to simplify authentication with Azure Artifacts when using various JavaScript/TypeScript package managers.

## Overview

Working with private packages in Azure Artifacts requires authentication token configuration. This module automates the process by leveraging your existing Azure CLI authentication to obtain and configure the necessary tokens.

## Installation

1. Clone this repository:

   ```powershell
   git clone https://github.com/scaryrawr/az-auth-helpers.pwsh.git
   ```

2. Import the module in your PowerShell session:

   ```powershell
   Import-Module -Path "./az-auth-helpers.psm1"
   ```

   For persistent use, add it to your PowerShell profile:

   ```powershell
   Add-Content -Path $PROFILE -Value 'Import-Module -Path "C:\path\to\az-auth-helpers.psm1"'
   ```

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and configured
- Active login session with Azure CLI (az login)
- Access to Azure Artifacts feeds
- Respective package managers installed for the functions you plan to use:
  - [Node.js and npm](https://nodejs.org/) for npm/npx functions
  - [Yarn](https://yarnpkg.com/getting-started/install) for yarn function
  - [pnpm](https://pnpm.io/installation) for pnpm/pnpx functions
  - [Rush](https://rushjs.io/pages/intro/get_started/) for rush/rush-pnpm functions

## Supported Package Managers

This module provides wrapper functions for the following package managers:

| Function   | Description |
|------------|-------------|
| yarn       | Wrapper for Yarn package manager |
| npm        | Wrapper for npm package manager |
| npx        | Wrapper for npx package runner |
| pnpm       | Wrapper for pnpm package manager |
| pnpx       | Wrapper for pnpx package runner |
| rush       | Wrapper for Rush monorepo tool |
| rush-pnpm  | Wrapper for Rush using pnpm |
| write-npm  | Utility to configure .npmrc with Azure tokens |

All package manager wrappers function exactly like the original commands - you use them in the same way as you would use the native commands. The only difference is that these wrappers automatically handle Azure Artifacts authentication for you:

```powershell
<command> [<command-specific arguments>]
```

For example:

```powershell
yarn build --to package
npm run test -- --watch
pnpm add --save-dev typescript
rush build --to some-project --verbose
```

The wrappers are completely transparent - they simply pass all arguments directly to the original command while setting the necessary authentication token.

The `write-npm` utility provides a `-Help` flag to display usage information:

```powershell
write-npm -Help
```

## Example Usage

```powershell
# Configure .npmrc with Azure Artifacts authentication
write-npm

# Run npm install with automatic Azure authentication
npm install

# Run pnpm install with automatic Azure authentication
pnpm install

# Run a rush command with automatic Azure authentication
rush update
```

## How It Works

All wrapper functions follow the same process:

1. Locate the original executable for the package manager
2. Get an Azure access token using the Azure CLI
3. Set the ARTIFACTS_ACCESSTOKEN environment variable
4. Call the actual executable with your arguments
5. Automatically remove the token from environment variables after execution

The wrappers are designed to be completely transparent in their behavior - they automatically forward all arguments to the original command without any additional handling or parsing. This ensures compatibility with all command-line options and arguments of the original tools.

### write-npm function

The `write-npm` function specifically:

1. Reads the local .npmrc file in your current directory
2. Extracts the registry URL
3. Adds authentication entries to your user .npmrc file (~/.npmrc)
4. Configures the file to use Azure CLI tokens for authentication

## Troubleshooting

### Common Issues

1. **"Original [command] executable not found."**
   - Ensure the package manager is installed and accessible in your PATH

2. **"No .npmrc file found in the current directory."**
   - Create or navigate to a directory with a valid .npmrc file

3. **"Registry field not found in the local .npmrc file."**
   - Ensure your local .npmrc contains a valid registry= line

4. **Azure CLI authentication errors**
   - Run az login to authenticate with Azure
   - Ensure you have access to the Azure Artifacts feed

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

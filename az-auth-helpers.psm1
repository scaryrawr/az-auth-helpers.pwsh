function yarn {
    Invoke-WithArtifactsToken -CommandName 'yarn' -Arguments $args
}

# Shared helper function to execute commands with Azure Artifacts token
function Invoke-WithArtifactsToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,
        
        [Parameter()]
        [object[]]$Arguments,

        [Parameter()]
        [string[]]$TokenEnvironmentVariableNames = @('ARTIFACTS_ACCESSTOKEN'),

        [Parameter()]
        [hashtable]$EnvironmentVariables = @{}
    )

    $environmentVariableNames = @($TokenEnvironmentVariableNames) + @($EnvironmentVariables.Keys)
    $environmentVariableNames = $environmentVariableNames | Select-Object -Unique
    $originalEnvironmentVariables = @{}

    foreach ($environmentVariableName in $environmentVariableNames) {
        $originalEnvironmentVariables[$environmentVariableName] = [Environment]::GetEnvironmentVariable($environmentVariableName, 'Process')
    }
    
    try {
        # Store the original command path
        $originalCommand = Get-Command -Name $CommandName -CommandType Application -ErrorAction SilentlyContinue | 
        Select-Object -First 1 -ExpandProperty Source
        
        if (-not $originalCommand) {
            Write-Error "Original $CommandName executable not found."
            return
        }
        
        # Get the Azure access token
        $artifactsAccessToken = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($artifactsAccessToken)) {
            Write-Error 'Failed to get an Azure Artifacts access token. Run az login and verify you have access to the feed.'
            return
        }

        foreach ($environmentVariableName in $TokenEnvironmentVariableNames) {
            [Environment]::SetEnvironmentVariable($environmentVariableName, $artifactsAccessToken, 'Process')
        }

        foreach ($environmentVariableName in $EnvironmentVariables.Keys) {
            [Environment]::SetEnvironmentVariable($environmentVariableName, $EnvironmentVariables[$environmentVariableName], 'Process')
        }
        
        # Call the actual executable (not our function)
        & $originalCommand @Arguments
    }
    finally {
        foreach ($environmentVariableName in $environmentVariableNames) {
            [Environment]::SetEnvironmentVariable($environmentVariableName, $originalEnvironmentVariables[$environmentVariableName], 'Process')
        }
    }
}

function bun {
    Invoke-WithArtifactsToken -CommandName 'bun' -Arguments $args
}

function npm {
    Invoke-WithArtifactsToken -CommandName 'npm' -Arguments $args
}

function npx {
    Invoke-WithArtifactsToken -CommandName 'npx' -Arguments $args
}

function pnpm {
    Invoke-WithArtifactsToken -CommandName 'pnpm' -Arguments $args
}

function pnpx {
    Invoke-WithArtifactsToken -CommandName 'pnpx' -Arguments $args
}

function Test-AzureArtifactsNuGetSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    $sourceUri = $null
    if (-not [System.Uri]::TryCreate($Source, [System.UriKind]::Absolute, [ref]$sourceUri)) {
        return $false
    }

    return $sourceUri.Host -eq 'pkgs.dev.azure.com' -or $sourceUri.Host.EndsWith('.pkgs.visualstudio.com', [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-NuGetConfigPaths {
    [CmdletBinding()]
    param()

    $configPaths = [System.Collections.Generic.List[string]]::new()
    $currentDirectory = Get-Item -LiteralPath (Get-Location)

    while ($currentDirectory) {
        foreach ($configFileName in @('NuGet.config', 'nuget.config', 'NuGet.Config')) {
            $configPath = Join-Path -Path $currentDirectory.FullName -ChildPath $configFileName
            if ((Test-Path -LiteralPath $configPath -PathType Leaf) -and -not $configPaths.Contains($configPath)) {
                $configPaths.Add($configPath)
            }
        }

        $currentDirectory = $currentDirectory.Parent
    }

    $applicationData = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
    if ($applicationData) {
        $userConfigPath = Join-Path -Path $applicationData -ChildPath 'NuGet\NuGet.Config'
        if ((Test-Path -LiteralPath $userConfigPath -PathType Leaf) -and -not $configPaths.Contains($userConfigPath)) {
            $configPaths.Add($userConfigPath)
        }
    }

    return $configPaths
}

function Get-NuGetArtifactsUriPrefixes {
    [CmdletBinding()]
    param()

    if (-not [string]::IsNullOrWhiteSpace($env:VSS_NUGET_URI_PREFIXES)) {
        return $env:VSS_NUGET_URI_PREFIXES
    }

    $uriPrefixes = [System.Collections.Generic.List[string]]::new()
    $uriPrefixes.Add('https://pkgs.dev.azure.com/')

    foreach ($configPath in Get-NuGetConfigPaths) {
        [xml]$nugetConfig = Get-Content -LiteralPath $configPath -Raw
        $packageSourceNodes = $nugetConfig.SelectNodes('//packageSources/add[@value]')

        foreach ($packageSourceNode in $packageSourceNodes) {
            $source = $packageSourceNode.GetAttribute('value').Trim()
            if ((Test-AzureArtifactsNuGetSource -Source $source) -and -not $uriPrefixes.Contains($source)) {
                $uriPrefixes.Add($source)
            }
        }
    }

    return ($uriPrefixes -join ';')
}

function Test-NuGetArtifactsCredentialProviderInstalled {
    [CmdletBinding()]
    param()

    $pluginsPath = Join-Path -Path $HOME -ChildPath '.nuget\plugins'
    if (-not (Test-Path -LiteralPath $pluginsPath -PathType Container)) {
        return $false
    }

    return $null -ne (Get-ChildItem -LiteralPath $pluginsPath -Recurse -Filter 'CredentialProvider.Microsoft*' -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Install-NuGetArtifactsCredentialProvider {
    [CmdletBinding()]
    param()

    if (Test-NuGetArtifactsCredentialProviderInstalled) {
        return
    }

    $installerPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "install-artifacts-credprovider-$PID.ps1"
    try {
        Invoke-WebRequest -Uri 'https://aka.ms/install-artifacts-credprovider.ps1' -OutFile $installerPath -UseBasicParsing
        & $installerPath -AddNetfx
        if (-not $?) {
            throw 'Azure Artifacts Credential Provider installation failed.'
        }
    }
    finally {
        Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-WithNuGetArtifactsToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,

        [Parameter()]
        [object[]]$Arguments
    )

    $originalCommand = Get-Command -Name $CommandName -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty Source

    if (-not $originalCommand) {
        Write-Error "Original $CommandName executable not found."
        return
    }

    Install-NuGetArtifactsCredentialProvider

    Invoke-WithArtifactsToken `
        -CommandName $CommandName `
        -Arguments $Arguments `
        -TokenEnvironmentVariableNames @('ARTIFACTS_ACCESSTOKEN', 'VSS_NUGET_ACCESSTOKEN') `
        -EnvironmentVariables @{ VSS_NUGET_URI_PREFIXES = (Get-NuGetArtifactsUriPrefixes) }
}

function dotnet {
    Invoke-WithNuGetArtifactsToken -CommandName 'dotnet' -Arguments $args
}

function nuget {
    Invoke-WithNuGetArtifactsToken -CommandName 'nuget' -Arguments $args
}

function write-npm {
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = 'Display help information about this command')]
        [switch]$Help
    )
    
    if ($Help) {
        Write-Host @'
DESCRIPTION:
    This function configures your user .npmrc file with authentication information 
    for Azure Artifacts feeds, based on your local .npmrc configuration.

USAGE:
    write-npm [-Help]

DETAILS:
    - Reads the local .npmrc file in your current directory
    - Extracts the registry URL 
    - Adds authentication entries to your user .npmrc file (~/.npmrc)
    - Uses the Azure CLI to obtain authentication tokens automatically

REQUIREMENTS:
    - A local .npmrc file must exist in your current directory
    - Azure CLI must be installed and you must be logged in
    - You must have access to the Azure Artifacts feed

NOTES:
    You will be prompted before any existing entries are modified.
'@
        return
    }
    
    # Check if .npmrc exists in the current directory
    $localNpmrcPath = Join-Path -Path (Get-Location) -ChildPath '.npmrc'
    if (-not (Test-Path -Path $localNpmrcPath)) {
        Write-Error 'No .npmrc file found in the current directory.'
        return
    }
    
    # Read the local .npmrc file
    $localNpmrcContent = Get-Content -Path $localNpmrcPath -Raw
    
    # Extract the registry field using regex
    $registryMatch = [regex]::Match($localNpmrcContent, 'registry=(.+)')
    if (-not $registryMatch.Success) {
        Write-Error 'Registry field not found in the local .npmrc file.'
        return
    }
    $registry = $registryMatch.Groups[1].Value.Trim()
    
    # Remove protocol if present to format properly for .npmrc
    if ($registry -match '^https?://(.+)') {
        $registryUrl = $matches[1]
    }
    else {
        $registryUrl = $registry
    }
    
    # Prepare the user's .npmrc path
    $userNpmrcPath = Join-Path -Path $HOME -ChildPath '.npmrc'
    
    # Prepare the entries to add
    $entriesToAdd = @"
//${registryUrl}:username=VssSessionToken
//${registryUrl}:_authToken=`${ARTIFACTS_ACCESSTOKEN}
//${registryUrl}:email=not-used@example.com
"@
    
    # Check if the user's .npmrc already exists
    if (Test-Path -Path $userNpmrcPath) {
        $userNpmrcContent = Get-Content -Path $userNpmrcPath -Raw
        # Check if entries for this registry URL already exist
        if ($userNpmrcContent -match [regex]::Escape($registryUrl)) {
            Write-Warning "Entries for $registryUrl already exist in $userNpmrcPath"
            
            # Ask user if they want to update the existing entries
            $confirmation = Read-Host 'Do you want to update the existing entries? (Y/N)'
            if ($confirmation -ne 'Y') {
                Write-Host 'Operation cancelled.'
                return
            }
            
            # Remove existing entries for this registry URL
            $pattern = "//$([regex]::Escape($registryUrl))[^`r`n]*`r?`n(;[^`r`n]*`r?`n)?"
            $userNpmrcContent = $userNpmrcContent -replace $pattern, ''
        }
        
        # Append the new entries
        $userNpmrcContent += "`r`n$entriesToAdd"
        Set-Content -Path $userNpmrcPath -Value $userNpmrcContent
    }
    else {
        # Create a new .npmrc file with our entries
        Set-Content -Path $userNpmrcPath -Value $entriesToAdd
    }
    
    Write-Host "Successfully updated $userNpmrcPath with entries for $registryUrl"
}

function rush {
    Invoke-WithArtifactsToken -CommandName 'rush' -Arguments $args
}

function Invoke-RushPnpm {
    Invoke-WithArtifactsToken -CommandName 'rush-pnpm' -Arguments $args
}

# Set an alias to maintain backward compatibility
Set-Alias -Name rush-pnpm -Value Invoke-RushPnpm

# Export the functions
Export-ModuleMember -Function yarn, bun, npm, npx, pnpm, pnpx, dotnet, nuget, rush, Invoke-RushPnpm, write-npm -Alias rush-pnpm

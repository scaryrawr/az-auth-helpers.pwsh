function yarn {
    # Pass all arguments directly to the original command
    Invoke-WithArtifactsToken -CommandName 'yarn' -Arguments $args
}

# Shared helper function to execute commands with Azure Artifacts token
function Invoke-WithArtifactsToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,
        
        [Parameter()]
        [object[]]$Arguments
    )
    
    try {
        # Store the original command path
        $originalCommand = Get-Command -Name $CommandName -CommandType Application -ErrorAction SilentlyContinue | 
        Select-Object -First 1 -ExpandProperty Source
        
        if (-not $originalCommand) {
            Write-Error "Original $CommandName executable not found."
            return
        }
        
        # Get the Azure access token
        $env:ARTIFACTS_ACCESSTOKEN = az account get-access-token --query accessToken -o tsv
        
        # Call the actual executable (not our function)
        & $originalCommand @Arguments
    }
    finally {
        Remove-Item -Path Env:ARTIFACTS_ACCESSTOKEN -ErrorAction SilentlyContinue
    }
}

function bun {
    # Pass all arguments directly to the original command
    Invoke-WithArtifactsToken -CommandName 'bun' -Arguments $args
}

function npm {
    # Pass all arguments directly to the original command
    Invoke-WithArtifactsToken -CommandName 'npm' -Arguments $args
}

function npx {
    # Pass all arguments directly to the original command
    Invoke-WithArtifactsToken -CommandName 'npx' -Arguments $args
}

function pnpm {
    # Pass all arguments directly to the original command
    Invoke-WithArtifactsToken -CommandName 'pnpm' -Arguments $args
}

function pnpx {
    # Pass all arguments directly to the original command
    Invoke-WithArtifactsToken -CommandName 'pnpx' -Arguments $args
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
    # Pass all arguments directly to the original command
    Invoke-WithArtifactsToken -CommandName 'rush' -Arguments $args
}

function Invoke-RushPnpm {
    # Pass all arguments directly to the original command
    Invoke-WithArtifactsToken -CommandName 'rush-pnpm' -Arguments $args
}

# Set an alias to maintain backward compatibility
Set-Alias -Name rush-pnpm -Value Invoke-RushPnpm

# Export the functions
Export-ModuleMember -Function yarn, bun, npm, npx, pnpm, pnpx, rush, Invoke-RushPnpm, write-npm -Alias rush-pnpm


<#
####################################################################################################
# File      : Build_Master.ps1                           
# Author    : Solumtochukwu Orji                                   
# Created   : 11/03/2025                                           
#                                                                  
# Usage	: Master Build Orchestrator - Detects artifact type and routes to appropriate build script
#
#                                                                  #
# MODIFIED BY                       DATE                  CHANGE DESCRIPTION         
#-------------------              ----------            -------------------------  
# Solumtochukwu Orji              11/03/2025            This script analyzes git diff to determine if .catalog and/or .zip files were changed.                                                         
######################################################################################################
<#
<#
    It then conditionally invokes the appropriate build script (catalog, setup, or both).
    Early exit if no relevant files are present.
.PARAMETER ArtifactType
    Filter by artifact type: 'Catalog', 'Setup', or 'All' (default).
    - Catalog: Only process .catalog files
    - Setup: Only process .zip files
    - All: Process both types if present
.EXAMPLE
    # Called with Catalog filter (typical use from ADO classic release task)
    .\Build_Master.ps1 -ArtifactType Catalog
    
    # Called with Setup filter
    .\Build_Master.ps1 -ArtifactType Setup
    
    # Called with All (backward compatible mode)
    .\Build_Master.ps1 -ArtifactType All
#>

$ErrorActionPreference = 'Stop'

# Set default artifact type (for when called without parameters)
$ArtifactType = 'All'

# CENTRAL SCRIPTS LOCATION - All projects use this shared path
$scriptDir = "E:\Southern\Apps\DevOps\Deploy"

# If running locally during development, use local directory fallback
if (-not (Test-Path $scriptDir)) {
    if ($MyInvocation.MyCommandPath) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommandPath
    }
    else {
        Write-Host "##vso[task.logissue type=error]Central script directory not found at E:\Southern\Apps\DevOps\Deploy"
        exit 1
    }
}

$sourceDir = $env:BUILD_SOURCESDIRECTORY
if (-not $sourceDir) {
    Write-Host "##vso[task.logissue type=error]BUILD_SOURCESDIRECTORY environment variable not set"
    exit 1
}

$stagingDir = if ($env:BUILD_ARTIFACTSTAGINGDIRECTORY) {
    $env:BUILD_ARTIFACTSTAGINGDIRECTORY
}
else {
    Write-Host "##vso[task.logissue type=error]BUILD_ARTIFACTSTAGINGDIRECTORY environment variable not set"
    exit 1
}

# Create separate subdirectories for each artifact type
$catalogArtifactDir = Join-Path $stagingDir "Catalog"
$setupArtifactDir = Join-Path $stagingDir "Setup"

# Ensure artifact directories exist
if (-not (Test-Path $catalogArtifactDir)) {
    New-Item -ItemType Directory -Path $catalogArtifactDir -Force | Out-Null
}
if (-not (Test-Path $setupArtifactDir)) {
    New-Item -ItemType Directory -Path $setupArtifactDir -Force | Out-Null
}

Write-Host "=========================================="
Write-Host "MASTER BUILD ORCHESTRATOR"
Write-Host "=========================================="
Write-Host "Artifact Type: $ArtifactType"
Write-Host "Script Directory: $scriptDir"
Write-Host "Source Directory: $sourceDir"
Write-Host "Staging Directory: $stagingDir"
Write-Host "Catalog Artifact Dir: $catalogArtifactDir"
Write-Host "Setup Artifact Dir: $setupArtifactDir"

Try {
    # Get changed files in current commit
    Write-Host "`n[*] Analyzing git changes..."
    $commit = git log -1 --pretty=format:'%H%n%an%n%s'
    Write-Host "Commit: $commit"
    
    $latest_commit = git diff --name-only HEAD^ HEAD | Where-Object { $_ -match '\.(catalog|zip)$' }
    
    if (-not $latest_commit) {
        Write-Host "`n=========================================="
        Write-Host "NO ARTIFACT FILES DETECTED"
        Write-Host "=========================================="
        Write-Host "No .catalog or .zip files detected in commit"
        Write-Host "This is a documentation/code-only change - no artifacts to build"
        Write-Host "Build will succeed without publishing artifacts"
        Write-Host "##vso[task.setvariable variable=NO_ARTIFACTS]true"
        Write-Host "`n=========================================="
        Write-Host "BUILD COMPLETED SUCCESSFULLY (NO ARTIFACTS)"
        Write-Host "=========================================="
        exit 0
    }
    
    Write-Host "Changed files with relevant extensions: $latest_commit"
    
    # Detect which artifact types are present
    $hasCatalogs = $null -ne ($latest_commit | Where-Object { $_ -match '\.catalog$' })
    $hasSetups = $null -ne ($latest_commit | Where-Object { $_ -match '\.zip$' })
    
    Write-Host "`n[*] Detection Results:"
    Write-Host "  Catalogs detected: $hasCatalogs"
    Write-Host "  Setups detected: $hasSetups"
    
    # Validate requested artifact type is present
    if ($ArtifactType -eq 'Catalog' -and -not $hasCatalogs) {
        Write-Host "`n##vso[task.logissue type=error]No .catalog files found but Catalog artifact type requested"
        exit 1
    }
    elseif ($ArtifactType -eq 'Setup' -and -not $hasSetups) {
        Write-Host "`n##vso[task.logissue type=error]No .zip files found but Setup artifact type requested"
        exit 1
    }
    
    # Route to appropriate build script(s)
    Write-Host "`n[*] Routing to build scripts..."
    
    if (($ArtifactType -eq 'Catalog' -or $ArtifactType -eq 'All') -and $hasCatalogs) {
        Write-Host "`n=========================================="
        Write-Host "INVOKING CATALOG BUILD"
        Write-Host "=========================================="
        
        # Set environment variable for catalog artifact directory
        $env:CATALOG_ARTIFACT_DIR = $catalogArtifactDir
        
        $catalogScript = Join-Path $scriptDir "Build_Catalog.ps1"
        if (Test-Path $catalogScript) {
            Write-Host "Executing: $catalogScript"
            & $catalogScript
            if ($LASTEXITCODE -ne 0) {
                Write-Host "##vso[task.logissue type=error]Catalog build failed with exit code $LASTEXITCODE"
                exit 1
            }
            Write-Host "##vso[task.setvariable variable=CATALOG_BUILD_EXECUTED]true"
            # Add build tag for Catalog artifacts
            Write-Host "##vso[build.addbuildtag]CatalogArtifact"
            Write-Host "[TAG APPLIED] CatalogArtifact"
        }
        else {
            Write-Host "##vso[task.logissue type=error]Catalog build script not found: $catalogScript"
            exit 1
        }
    }
    
    if (($ArtifactType -eq 'Setup' -or $ArtifactType -eq 'All') -and $hasSetups) {
        Write-Host "`n=========================================="
        Write-Host "INVOKING SETUP BUILD"
        Write-Host "=========================================="
        
        # Set environment variable for setup artifact directory
        $env:SETUP_ARTIFACT_DIR = $setupArtifactDir
        
        $setupScript = Join-Path $scriptDir "Build_Setup.ps1"
        if (Test-Path $setupScript) {
            Write-Host "Executing: $setupScript"
            & $setupScript
            if ($LASTEXITCODE -ne 0) {
                Write-Host "##vso[task.logissue type=error]Setup build failed with exit code $LASTEXITCODE"
                exit 1
            }
            Write-Host "##vso[task.setvariable variable=SETUP_BUILD_EXECUTED]true"
            # Add build tag for Setup artifacts
            Write-Host "##vso[build.addbuildtag]SetupArtifact"
            Write-Host "[TAG APPLIED] SetupArtifact"
        }
        else {
            Write-Host "##vso[task.logissue type=error]Setup build script not found: $setupScript"
            exit 1
        }
    }
    
    Write-Host "`n=========================================="
    Write-Host "BUILD ORCHESTRATION COMPLETED SUCCESSFULLY"
    Write-Host "=========================================="
    
}
Catch {
    $ErrorMessage = $_.Exception.Message
    $Exception_line_num = $_.InvocationInfo.ScriptLineNumber
    Write-Host "##vso[task.logissue type=error]Unhandled Exception: $ErrorMessage at line $Exception_line_num"
    exit 1
}

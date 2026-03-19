<#
.SYNOPSIS
    Catalog-specific build script - processes .catalog files only
.DESCRIPTION
    Detects and packages only .catalog files from the latest git commit.
    Fails early if no .catalog files are found.
    Publishes CatalogArtifact to build staging directory.
.EXAMPLE
    .\Build_Catalog.ps1
#>

$ErrorActionPreference = 'Stop'

# Get paths from ADO environment variables (required)
$sourceDir = $env:BUILD_SOURCESDIRECTORY
if (-not $sourceDir) {
    Write-Host "##vso[task.logissue type=error]BUILD_SOURCESDIRECTORY environment variable not set"
    exit 1
}

# Use the Catalog artifact directory set by Build_Master
$stagingDir = $env:CATALOG_ARTIFACT_DIR
if (-not $stagingDir) {
    Write-Host "##vso[task.logissue type=error]CATALOG_ARTIFACT_DIR environment variable not set"
    exit 1
}

Write-Host "`n[BUILD_CATALOG] Starting catalog-specific build..."
Write-Host "Source Directory: $sourceDir"
Write-Host "Staging Directory: $stagingDir"

Try {
    # Get latest commit changes
    Write-Host "`n[*] Detecting catalog files in commit..."
    $latest_commit = git diff --name-only HEAD^ HEAD | Where-Object { $_ -match '\.(catalog|zip)$' }
    
    if (-not $latest_commit) {
        Write-Host "##vso[task.logissue type=error]No .catalog or .zip files in commit"
        exit 1
    }
    
    # Filter for catalog files only
    $catalogs = $latest_commit | Where-Object { $_ -match '\.catalog$' }
    
    if (-not $catalogs) {
        Write-Host "##vso[task.logissue type=error]No .catalog files detected in commit"
        Write-Host "Catalog build requires at least one .catalog file"
        exit 1
    }
    
    Write-Host "##[section] Found $($catalogs.Count) catalog file(s)"
    $catalogs | ForEach-Object { Write-Host "  - $_" }
    
    # Create staging directory
    if (-not (Test-Path $stagingDir)) {
        New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null
        Write-Host "##[debug] Created staging directory: $stagingDir"
    }
    
    # Copy catalog files
    Write-Host "`n[*] Copying catalog files to staging directory..."
    foreach ($catalog in $catalogs) {
        $catalogpath = Split-Path -Path $catalog -Parent
        $catalogfilename = Split-Path -Path $catalog -Leaf
        $destPath = Join-Path $stagingDir $catalogpath
        
        if (-not (Test-Path $destPath)) {
            New-Item -Path $destPath -ItemType Directory -Force | Out-Null
        }
        
        $sourceFile = Join-Path $sourceDir $catalog
        Copy-Item -Path $sourceFile -Destination $destPath -Force -Recurse
        Write-Host "##[debug] Copied: $catalogfilename → $catalogpath"
    }
    
    Write-Host "##[section] Catalog artifact creation completed ($($catalogs.Count) file(s))"
    Write-Host "##[debug] Artifact staging path: $stagingDir"
    
}
Catch {
    $ErrorMessage = $_.Exception.Message
    $Exception_line_num = $_.InvocationInfo.ScriptLineNumber
    Write-Host "##vso[task.logissue type=error]Catalog build failed: $ErrorMessage (line $Exception_line_num)"
    exit 1
}

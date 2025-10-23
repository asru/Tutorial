<#
.SYNOPSIS
Deploys MacroQuest Lua scripts to your RedGuides installation.

.DESCRIPTION
Copies script folders to your RedGuides MacroQuest lua directory.
Default target: D:\ProgramData\RedGuides\redfetch\Downloads\VanillaMQ_LIVE\lua

.PARAMETER ScriptDir
Optional: Name of specific script directory to deploy (e.g., "vsCodeLua")
If omitted, all script directories will be deployed.

.PARAMETER MqPath
Optional: Override the default RedGuides lua path

.PARAMETER Preview
Switch to preview what would be deployed without making any changes

.PARAMETER NewName
Optional: Deploy the script folder under a different name (e.g., deploy MyTutorial as Tutorial)

.PARAMETER Force
Switch to skip confirmation when target folder exists

.EXAMPLE
# Preview deploying a specific script folder
.\deploy-to-mq.ps1 -ScriptDir MyTutorial -Preview

# Deploy MyTutorial as "Tutorial" in MacroQuest
.\deploy-to-mq.ps1 -ScriptDir MyTutorial -NewName Tutorial

# Preview the rename deployment
.\deploy-to-mq.ps1 -ScriptDir MyTutorial -NewName Tutorial -Preview

# Force deploy without confirmation
.\deploy-to-mq.ps1 -ScriptDir MyTutorial -Force

# Preview deploying all script folders
.\deploy-to-mq.ps1 -Preview

# Deploy to custom location
.\deploy-to-mq.ps1 -ScriptDir MyTutorial -MqPath "D:\Games\EQ\MacroQuest\lua"
#>

param(
    [string]$ScriptDir,
    [string]$NewName,
    [string]$MqPath = "D:\ProgramData\RedGuides\redfetch\Downloads\VanillaMQ_LIVE\lua",
    [switch]$Preview,
    [switch]$Force
)

if ($Preview) {
    Write-Host "`nPREVIEW MODE - No files will be copied`n" -ForegroundColor Yellow
}

if (-not (Test-Path $MqPath)) {
    Write-Error "RedGuides lua path not found: $MqPath"
    Write-Error "Please verify the path exists or provide the correct path with -MqPath"
    exit 1
}

# Get base directory (where this script lives)
$baseDir = $PSScriptRoot

$script:wasCancelled = $false

function Deploy-ScriptFolder {
    param (
        [string]$folderName
    )
    
    $sourcePath = Join-Path $baseDir $folderName
    if (-not (Test-Path $sourcePath -PathType Container)) {
        Write-Error "Script folder not found: $sourcePath"
        $script:wasCancelled = $true
        return $null
    }

    # Use NewName if provided, otherwise use original folder name
    $targetFolderName = if ($NewName) { $NewName } else { $folderName }
    $targetPath = Join-Path $MqPath $targetFolderName

    # Check if target exists and handle confirmation
    if (-not $Preview -and (Test-Path $targetPath)) {
        if (-not $Force) {
            Write-Host "`nWARNING: Target folder already exists: $targetPath" -ForegroundColor Yellow
            $confirm = Read-Host "Do you want to continue and potentially overwrite files? (y/N)"
            if ($confirm -ne "y") {
                Write-Host "Deployment cancelled by user" -ForegroundColor Yellow
                $script:wasCancelled = $true
                return $null
            }
        } else {
            Write-Host "Target folder exists, proceeding with -Force" -ForegroundColor Yellow
        }
    }
    
    # Get all files that would be deployed
    $rootFiles = Get-ChildItem -Path $sourcePath -File -Filter "*.lua"
    $subFolders = Get-ChildItem -Path $sourcePath -Directory
    $allFiles = @($rootFiles)
    
    if ($Preview) {
        Write-Host "Would deploy folder: $folderName" -ForegroundColor Cyan
        if ($NewName) {
            Write-Host "(Will be deployed as: $NewName)" -ForegroundColor DarkYellow
        }
        Write-Host "+ $targetFolderName/" -ForegroundColor DarkGray

        # Show warning if target exists
        if (Test-Path $targetPath) {
            Write-Host "! Target folder already exists, will prompt for confirmation unless -Force is used" -ForegroundColor Yellow
        }
        
        # Show root files
        $rootFiles | ForEach-Object {
            $destFile = Join-Path $targetPath $_.Name
            $fileSize = [math]::Round(($_.Length / 1KB), 2)
            Write-Host "  | $($_.Name) ($fileSize KB)" -ForegroundColor White
        }
        
        # Show subfolders and their files
        $subFolders | ForEach-Object {
            $subFolderName = $_.Name
            Write-Host "  + $subFolderName/" -ForegroundColor DarkGray
            
            $subFiles = Get-ChildItem -Path $_.FullName -File -Filter "*.lua"
            $allFiles += $subFiles
            
            $subFiles | ForEach-Object {
                $fileSize = [math]::Round(($_.Length / 1KB), 2)
                Write-Host "    | $($_.Name) ($fileSize KB)" -ForegroundColor White
            }
        }
    } else {
        # Create target directory and subfolders
        if (-not (Test-Path $targetPath)) {
            New-Item -ItemType Directory -Path $targetPath | Out-Null
        }
        
        # Copy root files
        $rootFiles | ForEach-Object {
            $destFile = Join-Path $targetPath $_.Name
            Copy-Item $_.FullName -Destination $destFile -Force
            Write-Host "Copied $($_.Name) -> $destFile"
        }
        
        # Copy subfolder files
        $subFolders | ForEach-Object {
            $subFolderName = $_.Name
            $targetSubFolder = Join-Path $targetPath $subFolderName
            
            if (-not (Test-Path $targetSubFolder)) {
                New-Item -ItemType Directory -Path $targetSubFolder -Force | Out-Null
            }
            
            Get-ChildItem -Path $_.FullName -File -Filter "*.lua" | ForEach-Object {
                $destFile = Join-Path $targetSubFolder $_.Name
                Copy-Item $_.FullName -Destination $destFile -Force
                Write-Host "Copied $subFolderName/$($_.Name)"
            }
        }
        
        Write-Host "`nDeployed $folderName to $targetPath"
    }
    
    return $allFiles
}

# Track total files for summary
$totalFiles = @()

# Deploy specific folder or all folders
if ($ScriptDir) {
    $totalFiles += Deploy-ScriptFolder $ScriptDir
}
else {
    # Get all immediate subdirectories that contain .lua files
    Get-ChildItem -Path $baseDir -Directory | Where-Object {
        Test-Path (Join-Path $_.FullName "*.lua")
    } | ForEach-Object {
        $totalFiles += Deploy-ScriptFolder $_.Name
    }
}

# Show summary
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Target path:    $MqPath"
Write-Host "Total files:    $($totalFiles.Count)"
Write-Host "Total size:     $([math]::Round(($totalFiles | Measure-Object -Property Length -Sum).Sum / 1KB, 2)) KB"

# Show appropriate final status
if ($Preview) {
    Write-Host "`nTo execute this deployment, run the same command without -Preview" -ForegroundColor Yellow
} elseif ($script:wasCancelled) {
    Write-Host "`nOperation cancelled - no files were deployed" -ForegroundColor Yellow
    Write-Host "Tip: Use -Force to skip confirmation prompt, or -Preview to see what would be copied" -ForegroundColor DarkGray
} else {
    Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
}
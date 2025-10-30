<#
.SYNOPSIS
Copies MacroQuest Lua scripts FROM your RedGuides installation TO your development environment.

.DESCRIPTION
Copies script folders from RedGuides MacroQuest lua directory to your development workspace,
with optional renaming of the target folder.

.PARAMETER ScriptDir
Name of the script directory to copy (e.g., "Tutorial")

.PARAMETER NewName
Optional: New name for the script folder in your dev environment (e.g., "MyTutorial")

.PARAMETER MqPath
Optional: Override the default RedGuides lua path

.PARAMETER Preview
Switch to preview what would be copied without making any changes

.EXAMPLE
# Preview what would be copied
.\copy-from-mq.ps1 -ScriptDir Tutorial -Preview

# Preview with rename
.\copy-from-mq.ps1 -ScriptDir Tutorial -NewName MyTutorial -Preview

# Copy Tutorial folder as-is
.\copy-from-mq.ps1 -ScriptDir Tutorial

# Copy and rename Tutorial to MyTutorial
.\copy-from-mq.ps1 -ScriptDir Tutorial -NewName MyTutorial
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ScriptDir,
    
    [string]$NewName,
    
    [string]$MqPath = "D:\ProgramData\RedGuides\redfetch\Downloads\VanillaMQ_LIVE\lua",

    [switch]$Preview
)

# Validate source path exists
if (-not (Test-Path $MqPath)) {
    Write-Error "RedGuides lua path not found: $MqPath"
    Write-Error "Please verify the path exists or provide the correct path with -MqPath"
    exit 1
}

# Get source folder path
$sourcePath = Join-Path $MqPath $ScriptDir
if (-not (Test-Path $sourcePath -PathType Container)) {
    Write-Error "Script folder not found: $sourcePath"
    exit 1
}

# Get this script's directory as base for dev environment
$baseDir = $PSScriptRoot

# Use NewName if provided, otherwise use original ScriptDir name
$targetFolderName = if ($NewName) { $NewName } else { $ScriptDir }
$targetPath = Join-Path $baseDir $targetFolderName

# Show preview header
if ($Preview) {
    Write-Host "`nPREVIEW MODE - No files will be copied`n" -ForegroundColor Yellow
}

# Check if target already exists
if (Test-Path $targetPath) {
    if ($Preview) {
        Write-Host "WARNING: Target folder already exists: $targetPath" -ForegroundColor Yellow
    } else {
        Write-Error "Target folder already exists: $targetPath"
        Write-Error "Please remove it first or choose a different name"
        exit 1
    }
}

# Preview or create target directory
if ($Preview) {
    Write-Host "Would create directory:" -ForegroundColor Cyan
    Write-Host "  $targetPath"
} else {
    New-Item -ItemType Directory -Path $targetPath | Out-Null
}

# Get files and immediate subfolders
$rootFiles = Get-ChildItem -Path $sourcePath -File
$subFolders = Get-ChildItem -Path $sourcePath -Directory

# Track all files for summary
$allFiles = @($rootFiles)

# Show preview or copy
Write-Host "`nFiles to be copied:" -ForegroundColor Cyan
Write-Host "+ $targetFolderName/" -ForegroundColor DarkGray

# Process root files
$rootFiles | ForEach-Object {
    $destFile = Join-Path $targetPath $_.Name
    $fileSize = [math]::Round(($_.Length / 1KB), 2)
    
    if ($Preview) {
        Write-Host "  | $($_.Name) ($fileSize KB)" -ForegroundColor White
    } else {
        Copy-Item $_.FullName -Destination $destFile -Force
        Write-Host "Copied $($_.Name) ($fileSize KB) -> $destFile"
    }
}

# Process each subfolder (one level deep)
$subFolders | ForEach-Object {
    $subFolderName = $_.Name
    $subFolderPath = $_.FullName
    $targetSubFolder = Join-Path $targetPath $subFolderName
    
    if ($Preview) {
        Write-Host "  + $subFolderName/" -ForegroundColor DarkGray
    } else {
        New-Item -ItemType Directory -Path $targetSubFolder -Force | Out-Null
    }
    
    # Get and process files in subfolder
    $subFiles = Get-ChildItem -Path $subFolderPath -File
    $allFiles += $subFiles
    
    $subFiles | ForEach-Object {
        $destFile = Join-Path $targetSubFolder $_.Name
        $fileSize = [math]::Round(($_.Length / 1KB), 2)
        
        if ($Preview) {
            Write-Host "    | $($_.Name) ($fileSize KB)" -ForegroundColor White
        } else {
            Copy-Item $_.FullName -Destination $destFile -Force
            Write-Host "Copied $subFolderName/$($_.Name) ($fileSize KB)"
        }
    }
}

# Summary
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Source folder:  $sourcePath"
Write-Host "Target folder:  $targetPath"
Write-Host "Subfolders:     $($subFolders.Count)"
Write-Host "Total files:    $($allFiles.Count)"
Write-Host "  Root files:   $($rootFiles.Count)"
$subFolders | ForEach-Object {
    $subFiles = Get-ChildItem -Path $_.FullName -File
    Write-Host "  .\$($_.Name)\:".PadRight(12) "$($subFiles.Count) files"
}
Write-Host "Total size:     $([math]::Round(($allFiles | Measure-Object -Property Length -Sum).Sum / 1KB, 2)) KB"

if ($Preview) {
    Write-Host "`nTo execute this copy, run the same command without -Preview" -ForegroundColor Yellow
} else {
    # Show quick help for deploying back
    Write-Host "`nTo deploy this script back to MacroQuest, use:"
    Write-Host ".\deploy-to-mq.ps1 -ScriptDir $targetFolderName"
}
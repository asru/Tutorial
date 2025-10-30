<#
.SYNOPSIS
Deploys the mycch script FROM your development environment TO MacroQuest for testing.

.DESCRIPTION
Copies the mycch script from your development workspace to the MacroQuest lua directory,
creating a backup of the existing version first.

.PARAMETER MqPath
Optional: Override the default RedGuides lua path

.PARAMETER NoBackup
Skip creating a backup of the existing MacroQuest version

.PARAMETER Preview
Switch to preview what would be deployed without making any changes

.EXAMPLE
# Preview deployment
.\deploy-to-mycch.ps1 -Preview

# Deploy with backup (default)
.\deploy-to-mycch.ps1

# Deploy without backup
.\deploy-to-mycch.ps1 -NoBackup
#>

param(
    [string]$MqPath = "D:\ProgramData\RedGuides\redfetch\Downloads\VanillaMQ_LIVE\lua",
    [switch]$NoBackup,
    [switch]$Preview
)

$ScriptDir = "mycch"

# Validate destination path exists
if (-not (Test-Path $MqPath)) {
    Write-Error "RedGuides lua path not found: $MqPath"
    Write-Error "Please verify the path exists or provide the correct path with -MqPath"
    exit 1
}

# Get this script's directory as source
$baseDir = $PSScriptRoot
$targetPath = Join-Path $MqPath $ScriptDir

# Show preview header
if ($Preview) {
    Write-Host "`nPREVIEW MODE - No files will be deployed`n" -ForegroundColor Yellow
}

# Create backup if target exists and backup not disabled
if ((Test-Path $targetPath) -and (-not $NoBackup) -and (-not $Preview)) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = Join-Path $MqPath "mycch_backup_$timestamp"
    Write-Host "Creating backup: $backupPath" -ForegroundColor Yellow
    Copy-Item -Path $targetPath -Destination $backupPath -Recurse -Force
    Write-Host "Backup created successfully" -ForegroundColor Green
}

# Ensure target directory exists
if (-not $Preview) {
    if (-not (Test-Path $targetPath)) {
        New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
    }
}

# Get files to deploy (deploy only the script file to avoid noise)
$rootFiles = Get-ChildItem -Path $baseDir -File -Filter "init.lua"

# Track all files for summary
$allFiles = @($rootFiles)

# Show what will be deployed
Write-Host "`nFiles to be deployed:" -ForegroundColor Cyan
Write-Host "From: $baseDir"
Write-Host "To:   $targetPath"
Write-Host ""

# Process root files
$rootFiles | ForEach-Object {
    $destFile = Join-Path $targetPath $_.Name
    $fileSize = [math]::Round(($_.Length / 1KB), 2)
    
    if ($Preview) {
        Write-Host "  $($_.Name) ($fileSize KB)" -ForegroundColor White
    } else {
        Copy-Item $_.FullName -Destination $destFile -Force
        Write-Host "Deployed $($_.Name) ($fileSize KB)"
    }
}

# Summary
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Source folder:  $baseDir"
Write-Host "Target folder:  $targetPath"
Write-Host "Total files:    $($allFiles.Count)"
Write-Host "Total size:     $([math]::Round(($allFiles | Measure-Object -Property Length -Sum).Sum / 1KB, 2)) KB"

if ($Preview) {
    Write-Host "`nTo execute deployment, run the same command without -Preview" -ForegroundColor Yellow
} else {
    Write-Host "`nDeployment complete! Your changes are now in MacroQuest." -ForegroundColor Green
    Write-Host "Test the script in EQ, then use Git to commit your changes when ready."
}

<#
.SYNOPSIS
Copies the mycch script FROM MacroQuest TO your development environment.

.DESCRIPTION
Copies the mycch script folder from RedGuides MacroQuest lua directory to your development workspace.

.PARAMETER MqPath
Optional: Override the default RedGuides lua path

.PARAMETER Preview
Switch to preview what would be copied without making any changes

.EXAMPLE
# Preview what would be copied
.\copy-from-mycch.ps1 -Preview

# Copy mycch folder from MacroQuest
.\copy-from-mycch.ps1
#>

param(
    [string]$MqPath = "D:\ProgramData\RedGuides\redfetch\Downloads\VanillaMQ_LIVE\lua",
    [switch]$Preview
)

$ScriptDir = "mycch"

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
$targetPath = $baseDir

# Show preview header
if ($Preview) {
    Write-Host "`nPREVIEW MODE - No files will be copied`n" -ForegroundColor Yellow
}

# Get files
$rootFiles = Get-ChildItem -Path $sourcePath -File

# Track all files for summary
$allFiles = @($rootFiles)

# Show preview or copy
Write-Host "`nFiles to be copied to $baseDir :" -ForegroundColor Cyan

# Process root files
$rootFiles | ForEach-Object {
    $destFile = Join-Path $targetPath $_.Name
    $fileSize = [math]::Round(($_.Length / 1KB), 2)
    
    if ($Preview) {
        Write-Host "  $($_.Name) ($fileSize KB)" -ForegroundColor White
    } else {
        Copy-Item $_.FullName -Destination $destFile -Force
        Write-Host "Copied $($_.Name) ($fileSize KB)"
    }
}

# Summary
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Source folder:  $sourcePath"
Write-Host "Target folder:  $targetPath"
Write-Host "Total files:    $($allFiles.Count)"
Write-Host "Total size:     $([math]::Round(($allFiles | Measure-Object -Property Length -Sum).Sum / 1KB, 2)) KB"

if ($Preview) {
    Write-Host "`nTo execute this copy, run the same command without -Preview" -ForegroundColor Yellow
} else {
    Write-Host "`nFiles copied successfully from MacroQuest to dev environment."
    Write-Host "To deploy back to MacroQuest, use: .\deploy-to-mycch.ps1"
}

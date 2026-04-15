<#
.SYNOPSIS
    Pack & import a Power Platform solution to any environment.

.DESCRIPTION
    Packs src/<SolutionName>/ back into a zip file then imports it into
    the specified environment.  DEV & UAT get unmanaged solutions.
    PROD always gets a managed solution (locks the app in production).

.PARAMETER Environment
    Target environment alias: dev | uat | prod

.PARAMETER SolutionName
    Name of the solution. Default: PowerAppsSolution

.PARAMETER Managed
    Force a managed import (automatically true when -Environment prod).

.EXAMPLE
    .\scripts\import-solution.ps1 -Environment uat
    .\scripts\import-solution.ps1 -Environment prod
    .\scripts\import-solution.ps1 -Environment dev -Managed

.NOTES
    Prerequisites:
      - pac CLI installed: https://aka.ms/PowerAppsCLI
      - Run after making & reviewing changes in src/<SolutionName>/
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "uat", "prod")]
    [string]$Environment,

    [string]$SolutionName = "PowerAppsSolution",

    [switch]$Managed
)

$envUrls = @{
    dev  = "https://org71df5d57.crm3.dynamics.com"
    uat  = "https://orgcbcd6963.crm3.dynamics.com"
    prod = "https://orgd8238401.crm3.dynamics.com"
}

$envUrl      = $envUrls[$Environment]
$srcFolder   = "src\$SolutionName"
$isManaged   = ($Managed -or $Environment -eq "prod")
$packageType = if ($isManaged) { "Managed" } else { "Unmanaged" }
$suffix      = if ($isManaged) { "_managed" } else { "_unmanaged" }
$outZip      = "out\$SolutionName$suffix.zip"

# ── Guard: source folder must exist ───────────────────────────────────────────
if (-not (Test-Path $srcFolder)) {
    Write-Error "Source folder '$srcFolder' not found. Run export-solution.ps1 first."
    exit 1
}

New-Item -ItemType Directory -Force -Path "out" | Out-Null

Write-Host ""
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "  IMPORT ($packageType): $SolutionName  →  $Environment" -ForegroundColor Cyan
Write-Host "  Target: $envUrl" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor DarkCyan

# ── Pack source into zip ───────────────────────────────────────────────────────
Write-Host "`n[1/3] Packing $srcFolder → $outZip ..." -ForegroundColor Yellow
pac solution pack `
    --zipfile $outZip `
    --folder $srcFolder `
    --packagetype $packageType `
    --processCanvasApps
if ($LASTEXITCODE -ne 0) { Write-Error "Pack failed."; exit 1 }

# ── Authenticate ───────────────────────────────────────────────────────────────
Write-Host "`n[2/3] Authenticating to $Environment..." -ForegroundColor Yellow
pac auth create --url $envUrl
if ($LASTEXITCODE -ne 0) { Write-Error "Authentication failed."; exit 1 }

# ── Import solution ────────────────────────────────────────────────────────────
Write-Host "`n[3/3] Importing to $Environment ($packageType)..." -ForegroundColor Yellow
pac solution import `
    --path $outZip `
    --force-overwrite `
    --publish-changes
if ($LASTEXITCODE -ne 0) { Write-Error "Import failed."; exit 1 }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Done!  $SolutionName deployed to $Environment." -ForegroundColor Green
if ($isManaged) {
    Write-Host "  (Managed - solution is locked in $Environment)" -ForegroundColor Gray
}
Write-Host "============================================================" -ForegroundColor Green

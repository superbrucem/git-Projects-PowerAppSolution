<#
.SYNOPSIS
    Export & unpack a Power Platform solution from any environment.

.DESCRIPTION
    Authenticates to the specified environment using pac CLI, exports the
    solution as unmanaged, then unpacks it into src/<SolutionName>/ so
    that AI tools (Augment Code) and Git can work with the source files.

.PARAMETER Environment
    Target environment alias: dev | uat | prod

.PARAMETER SolutionName
    Name of the solution to export. Default: PowerAppsSolution

.EXAMPLE
    .\scripts\export-solution.ps1 -Environment dev
    .\scripts\export-solution.ps1 -Environment dev -SolutionName PowerAppsSolution

.NOTES
    Prerequisites:
      - pac CLI installed: https://aka.ms/PowerAppsCLI
      - Run once to authenticate: pac auth create --url <env-url>
        OR this script will prompt you via browser (interactive auth)
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "uat", "prod")]
    [string]$Environment,

    [string]$SolutionName = "PowerAppsSolution"
)

$envUrls = @{
    dev  = "https://org71df5d57.crm3.dynamics.com"
    uat  = "https://orgcbcd6963.crm3.dynamics.com"
    prod = "https://orgd8238401.crm3.dynamics.com"
}

$envUrl    = $envUrls[$Environment]
$outZip    = "out\$SolutionName.zip"
$srcFolder = "src\$SolutionName"

# ── Ensure output folders exist ────────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path "out" | Out-Null
New-Item -ItemType Directory -Force -Path $srcFolder | Out-Null

Write-Host ""
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "  EXPORT: $SolutionName  ←  $Environment ($envUrl)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor DarkCyan

# ── Authenticate (interactive browser login) ───────────────────────────────────
Write-Host "`n[1/3] Authenticating to $Environment..." -ForegroundColor Yellow
pac auth create --url $envUrl
if ($LASTEXITCODE -ne 0) { Write-Error "Authentication failed."; exit 1 }

# ── Export solution ────────────────────────────────────────────────────────────
Write-Host "`n[2/3] Exporting $SolutionName (unmanaged)..." -ForegroundColor Yellow
pac solution export --path $outZip --name $SolutionName --overwrite
if ($LASTEXITCODE -ne 0) { Write-Error "Export failed."; exit 1 }

# ── Unpack solution (including canvas app .msapp → source) ────────────────────
Write-Host "`n[3/3] Unpacking to $srcFolder ..." -ForegroundColor Yellow
pac solution unpack `
    --zipfile $outZip `
    --folder $srcFolder `
    --processCanvasApps `
    --allowDelete
if ($LASTEXITCODE -ne 0) { Write-Error "Unpack failed."; exit 1 }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Done!  Source is in: $srcFolder" -ForegroundColor Green
Write-Host "  Review changes, let Augment AI edit, then:" -ForegroundColor Green
Write-Host "    git add src/" -ForegroundColor White
Write-Host "    git commit -m 'feat: <description of your change>'" -ForegroundColor White
Write-Host "    git push" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Green

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Status([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Cyan) {
    Write-Host "[npm] $Message" -ForegroundColor $Color
}

try {
    Write-Status 'Checking for the latest version...'
    $localVersion = ((& npm.cmd --version 2>$null) | Select-Object -First 1).Trim()
    $remoteVersion = ((& npm.cmd view npm version --registry=https://registry.npmjs.org 2>$null) | Select-Object -First 1).Trim()
    if (-not $localVersion -or -not $remoteVersion) { exit 1 }
    if ([version]$localVersion -ge [version]$remoteVersion) { exit 0 }
    if ([version]$localVersion -ge [version]$remoteVersion) {
        Write-Status "Already current (v$localVersion)." Green
        exit 0
    }

    Write-Status "Downloading and installing npm v$remoteVersion..." Yellow
    & npm.cmd install --global npm@latest --no-audit --no-fund --loglevel=error *> $null
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Status "Finished. npm v$remoteVersion is installed." Green
    exit 0
}
catch { exit 1 }
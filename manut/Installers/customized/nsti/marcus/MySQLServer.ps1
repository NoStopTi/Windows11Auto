<#
.SYNOPSIS
    Downloads and installs MySQL Community Server silently via winget.

.DESCRIPTION
    Ensures the Windows Package Manager (winget) is available on the machine,
    then uses it to download and install the latest MySQL Community Server
    package (published by Oracle) without any user interaction, prompt, or
    dialog. Only status messages are written to the console.

.PARAMETER PackageId
    Winget package identifier to install. Defaults to the official MySQL
    Community Server package.

.EXAMPLE
    .\MySQLServer.ps1
    Installs MySQL Server silently using the default package id.

.NOTES
    Run in a PowerShell session with Administrator privileges: the
    installation writes to Program Files, the registry, and creates the
    MySQL Windows service.
#>

[CmdletBinding()]
param(
    [string]$PackageId = "Oracle.MySQL"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}

function Get-WingetPath {
    # Bootstraps the App Installer package when winget isn't on PATH yet,
    # which happens on freshly provisioned machines where it was never
    # registered for the current user session.
    $existing = Get-Command winget -ErrorAction SilentlyContinue
    if ($existing) {
        return $existing.Source
    }

    Write-Step "winget not found, installing the App Installer package..."
    Add-AppxPackage -Path https://aka.ms/getwinget

    $wingetPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (-not (Test-Path $wingetPath)) {
        throw "Failed to bootstrap winget. Expected executable at $wingetPath."
    }

    $env:Path = "$env:LOCALAPPDATA\Microsoft\WindowsApps;$env:Path"
    return $wingetPath
}

function Test-MySQLServerInstalled {
    # A Windows service is the most reliable installed-marker for MySQL
    # Server, since the service name varies slightly by version (MySQL,
    # MySQL80, MySQL84, ...).
    return [bool](Get-Service -Name "MySQL*" -ErrorAction SilentlyContinue)
}

try {
    # 1. Skip if already installed
    Write-Step "Checking if MySQL Server is already installed..."
    if (Test-MySQLServerInstalled) {
        $service = Get-Service -Name "MySQL*" | Select-Object -First 1
        Write-Host "MySQL Server is already installed (service: $($service.Name))." -ForegroundColor Yellow
        Write-Host "Exiting without reinstalling." -ForegroundColor Yellow
        return
    }

    # 2. Resolve winget
    Write-Step "Resolving winget..."
    $winget = Get-WingetPath

    # 3. Install silently
    # --silent + --disable-interactivity: no UI, no prompts.
    # --accept-*-agreements: required for winget to run non-interactively.
    # -e: exact match on --id, avoids an ambiguous search picking the wrong package.
    Write-Step "Installing MySQL Server ($PackageId)..."
    $installArgs = @(
        "install",
        "--id", $PackageId,
        "-e",
        "--silent",
        "--disable-interactivity",
        "--accept-package-agreements",
        "--accept-source-agreements"
    )

    $process = Start-Process -FilePath $winget -ArgumentList $installArgs -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -ne 0) {
        throw "winget install failed with exit code $($process.ExitCode)."
    }

    Write-Host "Installation completed successfully." -ForegroundColor Green

    # 4. Verify
    Write-Step "Verifying the installation..."
    if (Test-MySQLServerInstalled) {
        $service = Get-Service -Name "MySQL*" | Select-Object -First 1
        Write-Host "Success! MySQL service '$($service.Name)' is $($service.Status)." -ForegroundColor Green
    }
    else {
        Write-Host "winget reported success, but no MySQL service was found yet. A logoff/reboot may be required for the service registration to complete." -ForegroundColor Yellow
    }

    Write-Host "Done." -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

<#
.SYNOPSIS
    Downloads and installs WinSCP silently via winget.

.DESCRIPTION
    Ensures the Windows Package Manager (winget) is available on the machine,
    then uses it to download and install the latest WinSCP package (published
    by WinSCP.WinSCP) without any user interaction, prompt, or dialog. Only
    status messages are written to the console.

.PARAMETER PackageId
    Winget package identifier to install. Defaults to the official WinSCP
    package.

.EXAMPLE
    .\WinScp.ps1
    Installs WinSCP silently using the default package id.

.NOTES
    Run in a PowerShell session with Administrator privileges: the
    installation writes to Program Files and the registry.
#>

[CmdletBinding()]
param(
    [string]$PackageId = "WinSCP.WinSCP"
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

function Test-WinSCPInstalled {
    # WinSCP does not register a service, so the installed-marker is its
    # uninstall registry entry. winget installs WinSCP per-user by default
    # (HKCU), but it can also land in HKLM/WOW6432Node depending on the
    # package's installer scope, so all three hives are checked.
    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    return [bool](
        Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "WinSCP*" }
    )
}

try {
    # 1. Skip if already installed
    Write-Step "Checking if WinSCP is already installed..."
    if (Test-WinSCPInstalled) {
        Write-Host "WinSCP is already installed." -ForegroundColor Yellow
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
    Write-Step "Installing WinSCP ($PackageId)..."
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
    if (Test-WinSCPInstalled) {
        Write-Host "Success! WinSCP was installed." -ForegroundColor Green
    }
    else {
        Write-Host "winget reported success, but the uninstall registry entry was not found yet." -ForegroundColor Yellow
    }

    Write-Host "Done." -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

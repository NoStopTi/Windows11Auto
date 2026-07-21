<#
.SYNOPSIS
    Downloads and installs Docker Desktop (latest stable version) silently.

.DESCRIPTION
    Downloads the official installer from Docker's stable "always latest"
    URL and runs it non-interactively (no windows, no clicks, no license
    prompt). Only status messages are written to the console.

.PARAMETER Backend
    Virtualization backend to configure Docker Desktop with. Accepts
    "wsl-2" (default) or "hyper-v".

.PARAMETER InstallerPath
    Local path where the installer is downloaded to before running it.

.EXAMPLE
    .\DockerDesktop.ps1
    Installs Docker Desktop silently using the WSL2 backend.

.NOTES
    Run in a PowerShell session with Administrator privileges: the
    installer writes to Program Files, the registry, and configures
    Windows optional features / services.

    This script only installs the application. The WSL2 backend still
    requires the "Windows Subsystem for Linux" and "Virtual Machine
    Platform" optional features to be enabled and a reboot performed
    beforehand — Docker Desktop's own installer handles that step, but
    a machine restart may still be required after it finishes.
#>

[CmdletBinding()]
param(
    [ValidateSet("wsl-2", "hyper-v")]
    [string]$Backend = "wsl-2",

    [string]$InstallerPath = "$env:TEMP\DockerDesktopInstaller.exe"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}

try {
    # 1. Check if Docker Desktop is already installed
    Write-Step "Checking if Docker Desktop is already installed..."
    $dockerDesktopExe = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktopExe) {
        Write-Host "Docker Desktop is already installed at $dockerDesktopExe." -ForegroundColor Yellow
        Write-Host "Exiting without reinstalling." -ForegroundColor Yellow
        return
    }

    # 2. Download the installer
    # This URL always points to the latest stable release, the same one
    # served by the "Download Docker Desktop" button on docker.com.
    $downloadUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"

    Write-Step "Downloading Docker Desktop..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $InstallerPath -UseBasicParsing
    $ProgressPreference = "Continue"

    if (-not (Test-Path $InstallerPath)) {
        throw "Failed to download the installer."
    }
    Write-Host "Download complete: $InstallerPath" -ForegroundColor Green

    # 3. Install silently
    # --quiet             -> no UI
    # --accept-license    -> skips the interactive license prompt
    # --always-run-service -> keeps the Docker service running after login
    # --backend=<value>   -> selects wsl-2 or hyper-v without the setup wizard
    Write-Step "Installing (backend: $Backend)..."
    $installArgs = @(
        "install",
        "--quiet",
        "--accept-license",
        "--always-run-service",
        "--backend=$Backend"
    )

    $process = Start-Process -FilePath $InstallerPath -ArgumentList $installArgs -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        throw "The installation failed with exit code $($process.ExitCode)."
    }

    Write-Host "Installation completed successfully." -ForegroundColor Green

    # 4. Verify the installation
    Write-Step "Verifying the installation..."
    if (Test-Path $dockerDesktopExe) {
        Write-Host "Success! Docker Desktop installed at $dockerDesktopExe." -ForegroundColor Green
        Write-Host "A reboot may be required before Docker Desktop can start the $Backend backend." -ForegroundColor Yellow
    }
    else {
        Write-Host "The installer reported success, but $dockerDesktopExe was not found." -ForegroundColor Yellow
    }

    # 5. Cleanup
    Write-Step "Cleaning up temporary files..."
    Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue

    Write-Host "Done." -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

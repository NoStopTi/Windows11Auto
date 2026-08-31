<#
.SYNOPSIS
    Downloads and installs Postman for Windows (64-bit) 100% silently.

.DESCRIPTION
    Downloads the installer from Postman's "always latest" download
    endpoint (the same one behind the "Download the app" button on
    postman.com) and runs it with the `--silent` switch. Postman does not
    ship an MSI and does not officially document any silent-install
    switch, but `--silent` is confirmed by the community (SCCM/enterprise
    deployments, see postmanlabs/postman-app-support#7615) to both suppress
    the installer UI and prevent Postman from auto-launching right after
    installation finishes — which is exactly what an unattended run needs.

    Postman installs per-user (a Squirrel/Electron-style bootstrapper)
    under %LOCALAPPDATA%\Postman and registers its uninstall entry under
    HKCU, not HKLM — there is no machine-wide install option for this app.

.PARAMETER DownloadFolder
    Temporary folder where the installer will be downloaded.

.EXAMPLE
    .\Postman.ps1
    Installs (or verifies) the current Postman release for the current user.

.NOTES
    Does NOT require Administrator privileges: Postman installs entirely
    under the current user's profile and only touches HKCU, never HKLM.
    Because of this, running the script under a different user account
    installs Postman for that user only, not machine-wide.
#>

[CmdletBinding()]
param(
    # Temporary folder where the installer will be downloaded
    [string]$DownloadFolder = "$env:TEMP\PostmanInstall"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}

function Test-PostmanInstalled {
    # Postman is a per-user install: it never registers anything under
    # HKLM, so only HKCU is checked here. The installed-app executable is
    # checked too since the registry entry can lag briefly right after
    # the installer process exits.
    $installedExe = Join-Path $env:LOCALAPPDATA "Postman\Postman.exe"

    $uninstallEntry = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "Postman*" }

    return (Test-Path $installedExe) -or [bool]$uninstallEntry
}

try {
    # 1. Check if Postman is already installed for the current user
    Write-Step "Checking if Postman is already installed..."
    if (Test-PostmanInstalled) {
        Write-Host "Postman is already installed for the current user." -ForegroundColor Yellow
        Write-Host "Exiting without reinstalling." -ForegroundColor Yellow
        return
    }

    # 2. Prepare the download folder
    Write-Step "Preparing temporary download folder ($DownloadFolder)..."
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }

    # 3. Download the installer
    # This URL always resolves to the current Postman release for 64-bit
    # Windows — the same endpoint the "Download the app" button on
    # postman.com points to, so it never needs to be updated by hand.
    $downloadUrl   = "https://dl.pstmn.io/download/latest/win64"
    $installerPath = Join-Path $DownloadFolder "PostmanSetup.exe"

    Write-Step "Downloading Postman..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
    $ProgressPreference = "Continue"

    if (-not (Test-Path $installerPath)) {
        throw "Failed to download the installer."
    }
    Write-Host "Download complete: $installerPath" -ForegroundColor Green

    # 4. Install silently
    #   --silent -> undocumented by Postman but confirmed by community
    #               enterprise deployments: skips the installer UI and
    #               also stops Postman from auto-launching once the
    #               install finishes (the same switch doubles as the
    #               silent uninstall switch for Update.exe --uninstall).
    Write-Step "Installing..."
    $process = Start-Process -FilePath $installerPath -ArgumentList "--silent" -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        throw "The installation failed with exit code $($process.ExitCode)."
    }

    Write-Host "Installation completed successfully." -ForegroundColor Green

    # 5. Verify
    Write-Step "Verifying the installation..."
    if (Test-PostmanInstalled) {
        Write-Host "Success! Postman was installed." -ForegroundColor Green
    }
    else {
        Write-Host "Installer reported success, but Postman was not found yet." -ForegroundColor Yellow
    }

    # 6. Cleanup of the downloaded installer
    Write-Step "Cleaning up temporary files..."
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue

    Write-Host "Done." -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

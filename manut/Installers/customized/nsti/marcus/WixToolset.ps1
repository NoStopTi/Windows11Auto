
<#
.SYNOPSIS
    Downloads and installs the WiX Toolset (latest v3.x release) 100% silently.

.DESCRIPTION
    Queries the GitHub API for the latest WiX Toolset v3 release
    (wixtoolset/wix3), downloads the official Burn-based installer (wixXXX.exe),
    and runs the silent installation (no windows, no clicks).
    Reports each step to the console (Downloading..., Installing..., etc).

.NOTES
    Run in a PowerShell session with Administrator privileges so the
    installation (which writes to Program Files and the registry) works without errors.
    Installs the build tools (candle.exe, light.exe, etc) used to author MSI/EXE installers.
#>

[CmdletBinding()]
param(
    # Temporary folder where the installer will be downloaded
    [string]$DownloadFolder = "$env:TEMP\WixToolsetInstall"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}

try {
    # 1. Check if WiX Toolset is already installed
    Write-Step "Checking if WiX Toolset is already installed..."
    $existingCandle = Get-ChildItem -Path "${env:ProgramFiles(x86)}\WiX Toolset v*\bin\candle.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existingCandle) {
        Write-Host "WiX Toolset is already installed: $($existingCandle.FullName)" -ForegroundColor Yellow
        Write-Host "Exiting without reinstalling." -ForegroundColor Yellow
        return
    }

    # 2. Prepare the download folder
    Write-Step "Preparing temporary download folder ($DownloadFolder)..."
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }

    # 3. Discover the latest version via the GitHub API
    Write-Step "Querying the latest WiX Toolset version..."
    $apiUrl = "https://api.github.com/repos/wixtoolset/wix3/releases/latest"
    $headers = @{ "User-Agent" = "installWixToolset-script" }
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers

    # Look for the installer asset (e.g. wix314.exe), skipping the .zip variants
    $asset = $release.assets | Where-Object { $_.name -match '^wix\d+\.exe$' } | Select-Object -First 1

    if (-not $asset) {
        throw "Could not find the installer executable in the latest release."
    }

    $downloadUrl   = $asset.browser_download_url
    $installerPath = Join-Path $DownloadFolder $asset.name

    Write-Host "Version found: $($release.tag_name)" -ForegroundColor Green

    # 4. Download the installer
    Write-Step "Downloading... ($($asset.name))"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

    if (-not (Test-Path $installerPath)) {
        throw "Failed to download the installer."
    }
    Write-Host "Download complete: $installerPath" -ForegroundColor Green

    # 5. Install silently
    # The WiX Toolset installer is a Burn bootstrapper, so it accepts these switches:
    #   /install   -> performs the installation (default action)
    #   /quiet     -> no UI, no prompts
    #   /norestart -> does not restart the computer
    #   /log       -> generates an installation log
    $logPath = Join-Path $DownloadFolder "wixtoolset-install.log"

    Write-Step "Installing..."
    $installArgs = @(
        "/install",
        "/quiet",
        "/norestart",
        "/log", "`"$logPath`""
    )

    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru

    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        throw "The installation failed with exit code $($process.ExitCode). See the log at $logPath"
    }

    Write-Host "Installation completed successfully." -ForegroundColor Green

    # 6. Verify the installation
    Write-Step "Verifying the installation..."
    $installedCandle = Get-ChildItem -Path "${env:ProgramFiles(x86)}\WiX Toolset v*\bin\candle.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installedCandle) {
        Write-Host "Success! WiX Toolset installed at $($installedCandle.Directory)" -ForegroundColor Green
    }
    else {
        Write-Host "Installer finished, but candle.exe was not found in the expected location." -ForegroundColor Yellow
    }

    # 7. Optional cleanup of the downloaded installer
    Write-Step "Cleaning up temporary files..."
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue

    Write-Host "Done." -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

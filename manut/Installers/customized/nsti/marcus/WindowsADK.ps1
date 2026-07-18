
<#
.SYNOPSIS
    Downloads and installs the complete Windows ADK (Assessment and Deployment Kit),
    including the Windows PE add-on, 100% silently.

.DESCRIPTION
    - Downloads the official installers from Microsoft's fwlink redirectors
      (ADK 10.1.26100.2454 - supports Windows 11 25H2/24H2 and earlier, Windows Server 2025/2022)
    - Installs ADKSetup.exe with every feature (/features +)
    - Installs the Windows PE add-on (AdkWinPeSetup.exe) with every feature (/features +)
    - Runs both installations without user interaction and with CEIP telemetry disabled
    - Only shows status messages (Downloading..., Installing..., etc)

.NOTES
    Run in a PowerShell session with Administrator privileges so the
    installation (which writes to Program Files and the registry) works without errors.
    Source: https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install
#>

[CmdletBinding()]
param(
    [string]$AdkUrl       = "https://go.microsoft.com/fwlink/?linkid=2289980",
    [string]$WinPeAddonUrl = "https://go.microsoft.com/fwlink/?linkid=2289981",
    [string]$DownloadFolder = "$env:TEMP\WindowsADKInstall"
)

$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Install-AdkComponent {
    param(
        [string]$Name,
        [string]$InstallerPath,
        [string]$LogPath
    )

    Write-Status "Installing $Name..."

    $installArgs = @(
        "/quiet",
        "/features", "+",
        "/ceip", "off",
        "/norestart",
        "/log", "`"$LogPath`""
    )

    $process = Start-Process -FilePath $InstallerPath -ArgumentList $installArgs -Wait -PassThru

    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        throw "$Name installation failed with exit code $($process.ExitCode). See the log at $LogPath"
    }

    Write-Status "$Name installed successfully."
}

try {
    # 1) Prepare the download folder
    Write-Status "Preparing temporary download folder ($DownloadFolder)..."
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }

    $adkInstallerPath      = Join-Path $DownloadFolder "AdkSetup.exe"
    $winPeInstallerPath    = Join-Path $DownloadFolder "AdkWinPeSetup.exe"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = "SilentlyContinue"

    # 2) Download the ADK installer
    Write-Status "Downloading Windows ADK..."
    Invoke-WebRequest -Uri $AdkUrl -OutFile $adkInstallerPath -UseBasicParsing

    if (-not (Test-Path $adkInstallerPath)) {
        throw "Failed to download the Windows ADK installer."
    }
    Write-Status "Windows ADK download complete."

    # 3) Download the Windows PE add-on installer
    Write-Status "Downloading Windows PE add-on..."
    Invoke-WebRequest -Uri $WinPeAddonUrl -OutFile $winPeInstallerPath -UseBasicParsing

    if (-not (Test-Path $winPeInstallerPath)) {
        throw "Failed to download the Windows PE add-on installer."
    }
    Write-Status "Windows PE add-on download complete."

    $ProgressPreference = "Continue"

    # 4) Silent installation - Windows ADK (all features)
    Install-AdkComponent -Name "Windows ADK" -InstallerPath $adkInstallerPath -LogPath "$DownloadFolder\adk-install.log"

    # 5) Silent installation - Windows PE add-on (all features)
    Install-AdkComponent -Name "Windows PE add-on" -InstallerPath $winPeInstallerPath -LogPath "$DownloadFolder\adkwinpe-install.log"

    # 6) Cleanup
    Write-Status "Cleaning up..."
    Remove-Item -Path $adkInstallerPath, $winPeInstallerPath -Force -ErrorAction SilentlyContinue
    Write-Status "Done! Windows ADK (complete, with Windows PE add-on) was installed successfully."
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

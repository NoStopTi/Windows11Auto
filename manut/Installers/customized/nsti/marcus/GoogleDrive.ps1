<#
.SYNOPSIS
    Downloads and installs Google Drive for desktop (latest version) silently.

.DESCRIPTION
    - Downloads the official installer from dl.google.com/drive-file-stream
    - Runs the installation without user interaction (--silent)
    - Only shows status messages (Downloading..., Installing..., etc)

.NOTES
    The GoogleDriveSetup.exe URL always points to the latest published version.
    Requires administrator privileges (machine-wide install).
#>

[CmdletBinding()]
param(
    [string]$DownloadUrl = "https://dl.google.com/drive-file-stream/GoogleDriveSetup.exe",
    [string]$InstallerPath = "$env:TEMP\GoogleDriveSetup.exe",
    [switch]$DesktopShortcut
)

$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

try {
    # 1) Download
    Write-Status "Downloading..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $ProgressPreference = "SilentlyContinue"  # speeds up Invoke-WebRequest
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing
    $ProgressPreference = "Continue"

    if (-not (Test-Path $InstallerPath)) {
        throw "Failed to download the installer."
    }
    Write-Status "Download complete."

    # 2) Silent installation
    Write-Status "Installing..."

    $installArgs = @("--silent", "--skip_launch_new", "--gsuite_shortcuts=false")
    if ($DesktopShortcut) {
        $installArgs += "--desktop_shortcut"
    }

    $process = Start-Process -FilePath $InstallerPath -ArgumentList $installArgs -PassThru -Wait

    if ($process.ExitCode -ne 0) {
        throw "The installer returned exit code $($process.ExitCode)."
    }
    Write-Status "Installation complete."

    # 3) Cleanup
    Write-Status "Cleaning up..."
    Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue
    Write-Status "Done! Google Drive was installed successfully."
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

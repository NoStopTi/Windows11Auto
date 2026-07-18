<#
.SYNOPSIS
    Downloads and installs Visual Studio Code (latest stable version) silently.

.DESCRIPTION
    - Downloads the latest official installer via update.code.visualstudio.com
    - Runs the installation without user interaction (Inno Setup /VERYSILENT)
    - Only shows status messages (Downloading..., Installing..., etc)

.NOTES
    By default downloads the "System" installer (for all users, x64).
    Use -Scope User to install only for the current user (does not require admin).
#>

[CmdletBinding()]
param(
    [ValidateSet("System", "User")]
    [string]$Scope = "System",

    [ValidateSet("x64", "arm64")]
    [string]$Arch = "x64",

    [string]$InstallerPath = "$env:TEMP\VSCodeSetup.exe"
)

$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

try {
    # 1) Build the download URL (always points to the latest "stable" build)
    $channel = if ($Scope -eq "User") { "win32-$Arch-user" } else { "win32-$Arch" }
    $DownloadUrl = "https://update.code.visualstudio.com/latest/$channel/stable"

    Write-Status "Downloading..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing
    $ProgressPreference = "Continue"

    if (-not (Test-Path $InstallerPath)) {
        throw "Failed to download the installer."
    }
    Write-Status "Download complete."

    # 2) Silent installation (Inno Setup installer)
    Write-Status "Installing..."

    $installArgs = @(
        "/VERYSILENT",
        "/NORESTART",
        "/MERGETASKS=!runcode",     # does not open VS Code at the end of the installation
        "/SUPPRESSMSGBOXES",
        "/LOG=$env:TEMP\VSCodeInstall.log"
    )

    $process = Start-Process -FilePath $InstallerPath -ArgumentList $installArgs -PassThru -Wait

    if ($process.ExitCode -ne 0) {
        throw "The installer returned exit code $($process.ExitCode). See the log at $env:TEMP\VSCodeInstall.log"
    }
    Write-Status "Installation complete."

    # 3) Cleanup
    Write-Status "Cleaning up..."
    Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue
    Write-Status "Done! Visual Studio Code was installed successfully."
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
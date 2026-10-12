<#
.SYNOPSIS
    Downloads and installs "PostgreSQL Explorer" (pgAdmin 4) 100% silently, straight from the official PostgreSQL FTP mirror.

.DESCRIPTION
    Queries the official pgAdmin 4 release index
    (https://ftp.postgresql.org/pub/pgadmin/pgadmin4/), the same source behind
    https://www.postgresql.org/ftp/pgadmin/pgadmin4/ and the pgAdmin download
    page, and discovers the newest published version that ships a Windows x64
    installer. It then downloads that installer directly and runs it with the
    Inno Setup silent switches. No winget, prompt, dialog or user interaction
    is involved; only status messages are written to the console.

.PARAMETER BaseUrl
    Root of the pgAdmin 4 release index on the PostgreSQL FTP mirror. Each
    release lives in a "vX.Y/" sub-folder, with the Windows installer under
    "vX.Y/windows/".

.PARAMETER DownloadFolder
    Temporary folder where the installer will be downloaded.

.EXAMPLE
    .\PostgreSQLExplorer.ps1
    Installs (or verifies) the latest pgAdmin 4 release.

.NOTES
    Run in a PowerShell session with Administrator privileges: the
    installer writes to Program Files and the registry.
    The version is resolved at run time, so the script never needs to be
    edited when a new pgAdmin 4 release is published.
#>

[CmdletBinding()]
param(
    [string]$BaseUrl = "https://ftp.postgresql.org/pub/pgadmin/pgadmin4",
    [string]$DownloadFolder = "$env:TEMP\PgAdminInstall"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}

function Test-PgAdminInstalled {
    # pgAdmin does not register a service, so the installed-marker is its
    # uninstall registry entry. Checked in the 64-bit, WOW6432Node 32-bit and
    # per-user hives, since the Inno Setup installer may land in any of them
    # depending on the install mode.
    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    return [bool](
        Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "pgAdmin 4*" }
    )
}

function Get-LatestPgAdminInstaller {
    # Returns @{ Version; Url } for the newest release that has a Windows x64
    # installer. Folders are compared as [version] (not as text) so v9.9 does
    # not outrank v9.18; the next-newest folder is tried when the newest one
    # has no Windows build yet (the FTP tree is populated per platform).
    $index = Invoke-WebRequest -Uri "$BaseUrl/" -UseBasicParsing
    $versions = [regex]::Matches($index.Content, 'href="v(\d+(?:\.\d+)+)/"') |
        ForEach-Object { [version]$_.Groups[1].Value } |
        Sort-Object -Descending -Unique

    foreach ($version in $versions) {
        $windowsUrl = "$BaseUrl/v$version/windows/"
        try {
            $listing = Invoke-WebRequest -Uri $windowsUrl -UseBasicParsing
        }
        catch {
            continue
        }

        $match = [regex]::Match($listing.Content, 'href="(pgadmin4-[\d.]+-x64\.exe)"')
        if ($match.Success) {
            return @{ Version = $version; Url = "$windowsUrl$($match.Groups[1].Value)" }
        }
    }

    throw "No Windows x64 installer was found under $BaseUrl."
}

try {
    # 1. Skip if already installed
    Write-Step "Checking if PostgreSQL Explorer (pgAdmin 4) is already installed..."
    if (Test-PgAdminInstalled) {
        Write-Host "PostgreSQL Explorer (pgAdmin 4) is already installed." -ForegroundColor Yellow
        Write-Host "Exiting without reinstalling." -ForegroundColor Yellow
        return
    }

    # 2. Resolve the latest release
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = "SilentlyContinue"

    Write-Step "Looking up the latest pgAdmin 4 release..."
    $release = Get-LatestPgAdminInstaller
    Write-Host "Latest version: $($release.Version)" -ForegroundColor Green

    # 3. Download the installer
    Write-Step "Preparing temporary download folder ($DownloadFolder)..."
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }

    $installerPath = Join-Path $DownloadFolder (Split-Path $release.Url -Leaf)
    Write-Step "Downloading $($release.Url)..."
    Invoke-WebRequest -Uri $release.Url -OutFile $installerPath -UseBasicParsing
    $ProgressPreference = "Continue"

    if (-not (Test-Path $installerPath)) {
        throw "Failed to download the installer."
    }
    Write-Host "Download complete: $installerPath" -ForegroundColor Green

    # 4. Install silently
    # Inno Setup switches: /VERYSILENT hides all UI, /SUPPRESSMSGBOXES answers
    # any message box with its default, /NORESTART blocks a reboot, and
    # /SP- skips the "This will install..." start prompt.
    Write-Step "Installing PostgreSQL Explorer (pgAdmin 4) $($release.Version)..."
    $process = Start-Process -FilePath $installerPath `
        -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-" `
        -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        throw "The installation failed with exit code $($process.ExitCode)."
    }

    Write-Host "Installation completed successfully." -ForegroundColor Green

    # 5. Verify
    Write-Step "Verifying the installation..."
    if (Test-PgAdminInstalled) {
        Write-Host "Success! PostgreSQL Explorer (pgAdmin 4) was installed." -ForegroundColor Green
    }
    else {
        Write-Host "Installer reported success, but the uninstall registry entry was not found yet." -ForegroundColor Yellow
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

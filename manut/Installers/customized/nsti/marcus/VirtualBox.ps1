<#
.SYNOPSIS
    Downloads and installs Oracle VM VirtualBox for Windows (64-bit) 100%
    silently.

.DESCRIPTION
    Resolves the current stable release from VirtualBox's own download
    server (download.virtualbox.org), which publishes the latest version
    number in a plain-text LATEST.TXT file. That version's directory
    listing is then parsed to find the exact Windows installer filename
    (it embeds a build/revision number that is not present in LATEST.TXT,
    e.g. VirtualBox-7.2.8-173730-Win.exe), and the matching SHA256SUMS
    entry published in the same directory is used to verify the download
    before running the silent installation.

    VirtualBox's installer does not expose a documented `-silent`/`--silent`
    flag in its official user manual, but it is a long-standing,
    community-confirmed switch used across enterprise deployment tooling
    (SCCM/Intune) to suppress all UI. It is combined here with
    `--msiparams REBOOT=ReallySuppress REBOOTPROMPT=ReallySuppress` so the
    underlying MSI never reboots the machine or prompts about it, even
    though installing VirtualBox's network drivers can request a reboot.

.PARAMETER DownloadFolder
    Temporary folder where the installer will be downloaded.

.EXAMPLE
    .\VirtualBox.ps1
    Installs (or verifies) the current stable VirtualBox release.

.NOTES
    Run in a PowerShell session with Administrator privileges: the
    installation writes to Program Files, the registry, and installs
    kernel-mode network/USB drivers (HKLM-wide, not per-user).
#>

[CmdletBinding()]
param(
    # Temporary folder where the installer will be downloaded
    [string]$DownloadFolder = "$env:TEMP\VirtualBoxInstall"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}

function Test-VirtualBoxInstalled {
    # VirtualBox installs machine-wide only (HKLM) via its bundled MSI;
    # there is no per-user install mode, so HKCU is not checked.
    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    # The installer registers the uninstall entry as "Oracle VirtualBox
    # <version>" (no "VM" in the DisplayName, unlike the product's marketing
    # name), confirmed against the actual registry entry after installing.
    return [bool](
        Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "Oracle VirtualBox*" }
    )
}

function Get-VirtualBoxLatestVersion {
    # download.virtualbox.org publishes the current stable version number
    # (and nothing else) at this well-known path.
    $version = (Invoke-WebRequest -Uri "https://download.virtualbox.org/virtualbox/LATEST.TXT" -UseBasicParsing).Content.Trim()

    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Unexpected content from LATEST.TXT: '$version'."
    }

    return $version
}

function Get-VirtualBoxWindowsAsset {
    param(
        [Parameter(Mandatory)] [string]$Version
    )

    # The per-version directory listing is a plain HTML index; the Windows
    # installer filename embeds a build/revision number
    # (e.g. VirtualBox-7.2.8-173730-Win.exe) that isn't published anywhere
    # else, so it has to be scraped from here.
    $indexUrl = "https://download.virtualbox.org/virtualbox/$Version/"
    $index    = Invoke-WebRequest -Uri $indexUrl -UseBasicParsing
    $match    = [regex]::Match($index.Content, "VirtualBox-$([regex]::Escape($Version))-\d+-Win\.exe")

    if (-not $match.Success) {
        throw "Could not find the Windows installer for VirtualBox $Version in $indexUrl."
    }

    $fileName = $match.Value

    # The SHA256SUMS file published alongside the installer is used to
    # verify integrity before running an unattended, unsupervised install.
    $sumsUrl  = "${indexUrl}SHA256SUMS"
    $sums     = (Invoke-WebRequest -Uri $sumsUrl -UseBasicParsing).Content
    $sumMatch = [regex]::Match($sums, "(?m)^([0-9a-fA-F]{64})\s+\*?$([regex]::Escape($fileName))\s*$")

    if (-not $sumMatch.Success) {
        throw "Could not find a SHA256 checksum for $fileName in $sumsUrl."
    }

    return [PSCustomObject]@{
        FileName    = $fileName
        DownloadUrl = "$indexUrl$fileName"
        Sha256      = $sumMatch.Groups[1].Value.ToUpper()
    }
}

try {
    # 1. Check if VirtualBox is already installed
    Write-Step "Checking if VirtualBox is already installed..."
    if (Test-VirtualBoxInstalled) {
        Write-Host "VirtualBox is already installed." -ForegroundColor Yellow
        Write-Host "Exiting without reinstalling." -ForegroundColor Yellow
        return
    }

    # 2. Prepare the download folder
    Write-Step "Preparing temporary download folder ($DownloadFolder)..."
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }

    # 3. Resolve the current release and its Windows installer asset
    Write-Step "Resolving the current VirtualBox release..."
    $version = Get-VirtualBoxLatestVersion
    Write-Host "Version found: $version" -ForegroundColor Green

    Write-Step "Resolving the Windows installer download link..."
    $asset         = Get-VirtualBoxWindowsAsset -Version $version
    $installerPath = Join-Path $DownloadFolder $asset.FileName

    # 4. Download the installer
    Write-Step "Downloading... ($($asset.FileName))"
    Invoke-WebRequest -Uri $asset.DownloadUrl -OutFile $installerPath -UseBasicParsing

    if (-not (Test-Path $installerPath)) {
        throw "Failed to download the installer."
    }

    # 5. Verify integrity against the checksum published by the same server
    Write-Step "Verifying integrity (SHA256)..."
    $actualHash = (Get-FileHash -Path $installerPath -Algorithm SHA256).Hash
    if ($actualHash -ne $asset.Sha256) {
        throw "SHA256 mismatch: expected $($asset.Sha256), got $actualHash. Aborting install of a possibly corrupted/tampered file."
    }
    Write-Host "Checksum verified." -ForegroundColor Green
    Write-Host "Download complete: $installerPath" -ForegroundColor Green

    # 6. Install silently
    #   --silent    -> no UI, no prompts (undocumented but the standard
    #                  switch used for unattended VirtualBox deployments)
    #   --msiparams -> forwarded to the embedded MSI; ReallySuppress on
    #                  both REBOOT and REBOOTPROMPT stops the network
    #                  driver install from rebooting the machine or asking
    #                  about it
    Write-Step "Installing..."
    $installArgs = @(
        "--silent",
        "--msiparams", "REBOOT=ReallySuppress", "REBOOTPROMPT=ReallySuppress"
    )

    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru

    # 3010 is the standard MSI "success, reboot required" exit code; the
    # network/USB kernel drivers can request one even with REBOOT=ReallySuppress
    # honored (the suppression just stops it from happening automatically).
    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        throw "The installation failed with exit code $($process.ExitCode)."
    }
    if ($process.ExitCode -eq 3010) {
        Write-Host "Installation completed successfully (a reboot is pending)." -ForegroundColor Yellow
    }
    else {
        Write-Host "Installation completed successfully." -ForegroundColor Green
    }

    # 7. Verify
    Write-Step "Verifying the installation..."
    if (Test-VirtualBoxInstalled) {
        Write-Host "Success! VirtualBox was installed." -ForegroundColor Green
    }
    else {
        Write-Host "Installer reported success, but the uninstall registry entry was not found yet." -ForegroundColor Yellow
    }

    # 8. Cleanup of the downloaded installer
    Write-Step "Cleaning up temporary files..."
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue

    Write-Host "Done." -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

<#
.SYNOPSIS
    Downloads and installs FileZilla Client for Windows (64-bit) 100% silently.

.DESCRIPTION
    Resolves the current stable release from SourceForge (FileZilla's
    official mirror/distribution partner) via its best_release.json API,
    downloads the clean installer (no bundled third-party offers), verifies
    its MD5 checksum against the value published by that same API, and runs
    the silent (NSIS) installation for all users. Reports each step to the
    console.

    Two sources were deliberately ruled out:
    - winget: the FileZilla Client package was removed from winget-pkgs at
      the request of the FileZilla developers, so no package id exists
      there anymore.
    - download.filezilla-project.org (the vendor's own site): its "clean"
      (non-bundled) build is blocked from direct/scripted download (returns
      an HTML anti-bot page instead of the file), while the build that IS
      directly downloadable there has "_sponsored" in its filename and is
      documented to bundle third-party adware-flagged offers — unacceptable
      for an unattended install pushed to many machines.

    SourceForge requires a short-lived signed token to serve the binary
    directly; requesting the file without one returns an HTML "please wait"
    interstitial page instead. That interstitial page itself embeds a
    freshly-signed direct link, so this script fetches the interstitial
    once and extracts the real link from it before downloading.

.PARAMETER DownloadFolder
    Temporary folder where the installer will be downloaded.

.EXAMPLE
    .\FileZilla.ps1
    Installs (or verifies) the current stable FileZilla Client release.

.NOTES
    Run in a PowerShell session with Administrator privileges so the
    installation (which writes to Program Files and the registry) works
    without errors.
#>

[CmdletBinding()]
param(
    # Temporary folder where the installer will be downloaded
    [string]$DownloadFolder = "$env:TEMP\FileZillaInstall"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}

function Test-FileZillaInstalled {
    # FileZilla does not register a service, so the installed-marker is its
    # uninstall registry entry. The /user=all silent switch installs
    # machine-wide (HKLM), but WOW6432Node is checked too since FileZilla
    # ships a 32-bit-registered uninstall entry on some builds.
    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    # The installer registers the uninstall entry as "FileZilla <version>"
    # (no "Client" in the DisplayName), so the match must not require it.
    return [bool](
        Get-ItemProperty -Path $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "FileZilla *" }
    )
}

function Get-FileZillaRelease {
    # SourceForge's own API for "what is the current recommended release",
    # kept in sync by the FileZilla project itself.
    $release = Invoke-RestMethod -Uri "https://sourceforge.net/projects/filezilla/best_release.json"
    $windows = $release.platform_releases.windows

    if (-not $windows -or -not $windows.filename) {
        throw "Could not resolve the current FileZilla Client Windows release from SourceForge."
    }

    return $windows
}

function Resolve-SourceForgeDirectUrl {
    param(
        [Parameter(Mandatory)] [string]$InterstitialUrl
    )

    # The interstitial page (meant to auto-redirect browsers via meta-refresh)
    # embeds a freshly-signed link of the form:
    #   https://downloads.sourceforge.net/project/<...>?ts=...&use_mirror=...&r=
    # which is the actual link needed to fetch the binary directly.
    $page = Invoke-WebRequest -Uri $InterstitialUrl -UseBasicParsing
    $pattern = 'https://downloads\.sourceforge\.net/project/[^\s"''<>]+\.exe\?[^\s"''<>]*'
    $match = [regex]::Match($page.Content, $pattern)

    if (-not $match.Success) {
        throw "Could not extract the direct download link from SourceForge's response. The page format may have changed."
    }

    return ($match.Value -replace '&amp;', '&')
}

try {
    # 1. Check if FileZilla Client is already installed
    Write-Step "Checking if FileZilla Client is already installed..."
    if (Test-FileZillaInstalled) {
        Write-Host "FileZilla Client is already installed." -ForegroundColor Yellow
        Write-Host "Exiting without reinstalling." -ForegroundColor Yellow
        return
    }

    # 2. Prepare the download folder
    Write-Step "Preparing temporary download folder ($DownloadFolder)..."
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }

    # 3. Resolve the current release and its real download link
    Write-Step "Resolving the current FileZilla Client release from SourceForge..."
    $release       = Get-FileZillaRelease
    $fileName      = $release.filename.TrimStart('/')
    $interstitial  = "https://sourceforge.net/projects/filezilla/files/$fileName/download"
    $installerPath = Join-Path $DownloadFolder $fileName

    Write-Host "Version found: $fileName" -ForegroundColor Green

    Write-Step "Resolving the direct download link..."
    $directUrl = Resolve-SourceForgeDirectUrl -InterstitialUrl $interstitial

    # 4. Download the installer
    Write-Step "Downloading..."
    Invoke-WebRequest -Uri $directUrl -OutFile $installerPath -UseBasicParsing

    if (-not (Test-Path $installerPath)) {
        throw "Failed to download the installer."
    }

    # 5. Verify integrity against the checksum published by the same API
    Write-Step "Verifying integrity (MD5)..."
    $actualHash = (Get-FileHash -Path $installerPath -Algorithm MD5).Hash
    if ($actualHash -ne $release.md5sum.ToUpper()) {
        throw "MD5 mismatch: expected $($release.md5sum), got $actualHash. Aborting install of a possibly corrupted/tampered file."
    }
    Write-Host "Checksum verified." -ForegroundColor Green
    Write-Host "Download complete: $installerPath" -ForegroundColor Green

    # 6. Install silently
    #   /S          -> silent (NSIS), no UI, no prompts
    #   /user=all   -> install for all users (machine-wide) instead of
    #                  per-user, so every account on the machine gets it
    Write-Step "Installing..."
    $installArgs = @("/S", "/user=all")

    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        throw "The installation failed with exit code $($process.ExitCode)."
    }

    Write-Host "Installation completed successfully." -ForegroundColor Green

    # 7. Verify
    Write-Step "Verifying the installation..."
    if (Test-FileZillaInstalled) {
        Write-Host "Success! FileZilla Client was installed." -ForegroundColor Green
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

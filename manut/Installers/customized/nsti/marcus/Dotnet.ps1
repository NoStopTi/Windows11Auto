
<#
.SYNOPSIS
    Installs the .NET SDK versions 9.0, 10.0 and 11.0 side-by-side, 100% silently.

.DESCRIPTION
    Uses Microsoft's official dotnet-install.ps1 script to install multiple
    .NET SDK major versions into the same shared install directory. .NET SDKs
    are designed to coexist side-by-side (each version lives in its own
    versioned sub-folder), so running this script installs/updates all
    requested channels without removing previously installed ones.

    For each channel in -Channels:
    - Skips it if an SDK matching that major.minor version is already
      installed (checked via `dotnet --list-sdks`).
    - Otherwise downloads (once) and runs the official dotnet-install.ps1
      script for that channel.

    Only status messages are printed (Downloading..., Installing..., etc.),
    no prompts, no dialogs.

.PARAMETER Channels
    .NET SDK channels (major.minor) to install. Defaults to 9.0, 10.0 and 11.0.
    Note: 11.0 may only have preview/RC builds available until its General
    Availability release; dotnet-install.ps1 will still install the latest
    build published for that channel.

.PARAMETER InstallDir
    Folder where the SDKs are installed. Defaults to the current user's
    local .NET install folder so no Administrator privileges are required.

.EXAMPLE
    .\Dotnet.ps1
    Installs (or verifies) .NET SDK 9.0, 10.0 and 11.0.

.EXAMPLE
    .\Dotnet.ps1 -Channels '9.0','10.0'
    Installs only the 9.0 and 10.0 SDKs.

.NOTES
    Requires internet access to dot.net (installer script) and the .NET
    release CDN (SDK archives).
#>

[CmdletBinding()]
param(
    [string[]]$Channels = @('9.0', '10.0', '11.0'),
    [string]$InstallDir = "$env:LOCALAPPDATA\Microsoft\dotnet",
    [string]$DownloadFolder = "$env:TEMP\DotnetInstall"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}

# Returns the installed SDK versions (e.g. "9.0.101") reported by `dotnet --list-sdks`,
# or $null if the `dotnet` command is not available yet.
function Get-InstalledSdkVersions {
    param([string]$DotnetExe)

    if (-not (Test-Path $DotnetExe)) {
        return $null
    }
    try {
        # Each line looks like: "9.0.101 [C:\Users\me\AppData\Local\Microsoft\dotnet\sdk]"
        return & $DotnetExe --list-sdks 2>$null | ForEach-Object { ($_ -split '\s+')[0] }
    }
    catch {
        return $null
    }
}

try {
    # 1. Prepare the working folder
    Write-Step "Preparing temporary working folder ($DownloadFolder)..."
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir | Out-Null
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = "SilentlyContinue"

    # 2. Download the official dotnet-install.ps1 script once, reused for every channel
    Write-Step "Downloading .NET SDK installer script..."
    $dotnetInstallScript = Join-Path $DownloadFolder "dotnet-install.ps1"
    Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $dotnetInstallScript -UseBasicParsing

    $ProgressPreference = "Continue"

    $dotnetExe = Join-Path $InstallDir "dotnet.exe"
    $failedChannels = @()

    # 3. Install each requested channel, skipping the ones already present
    foreach ($channel in $Channels) {
        Write-Step "Checking channel $channel..."
        $installedVersions = Get-InstalledSdkVersions -DotnetExe $dotnetExe
        $alreadyInstalled = $installedVersions | Where-Object { $_ -like "$channel.*" }

        if ($alreadyInstalled) {
            Write-Host ".NET SDK $channel already installed: $($alreadyInstalled -join ', ')" -ForegroundColor Yellow
            continue
        }

        try {
            Write-Step "Installing .NET SDK $channel..."
            & $dotnetInstallScript -Channel $channel -InstallDir $InstallDir -NoPath
            if ($LASTEXITCODE -ne 0) {
                throw ".NET SDK $channel installation failed with exit code $LASTEXITCODE."
            }
            Write-Host ".NET SDK $channel installed." -ForegroundColor Green
        }
        catch {
            # Keep going with the remaining channels (e.g. a not-yet-released channel
            # like 11.0 shouldn't block 9.0/10.0 from being installed).
            Write-Host "WARNING: could not install .NET SDK $channel - $($_.Exception.Message)" -ForegroundColor Yellow
            $failedChannels += $channel
        }
    }

    # 4. Make sure the install folder is on PATH for this session and set DOTNET_ROOT
    $env:Path = "$InstallDir;$env:Path"
    $env:DOTNET_ROOT = $InstallDir

    # 5. Verify the installation
    Write-Step "Verifying the installation..."
    $finalVersions = Get-InstalledSdkVersions -DotnetExe $dotnetExe
    if ($finalVersions) {
        Write-Host "Installed .NET SDKs:" -ForegroundColor Green
        $finalVersions | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }
    }
    else {
        Write-Host "dotnet installed, but not found in the current session's PATH. Open a new terminal to use the 'dotnet' command." -ForegroundColor Yellow
    }

    if ($failedChannels.Count -gt 0 -and $failedChannels.Count -eq $Channels.Count) {
        throw "All requested channels failed to install: $($failedChannels -join ', ')"
    }
    elseif ($failedChannels.Count -gt 0) {
        Write-Host "Completed with warnings. Channels not installed: $($failedChannels -join ', ')" -ForegroundColor Yellow
    }

    Write-Host "Done." -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}


<#
.SYNOPSIS
    Installs the WiX Toolset (latest v5.x, .NET global tool) 100% silently.

.DESCRIPTION
    - Ensures the .NET SDK is available (installs it silently via Microsoft's
      official dotnet-install.ps1 script if `dotnet` is not found)
    - Installs the WiX Toolset as a .NET global tool: `dotnet tool install --global wix`
    - Adds the global tools folder to PATH for the current session and verifies
      the installation by running `wix --version`
    - Only shows status messages (Downloading..., Installing..., etc), no prompts

.NOTES
    This is the modern, Microsoft-recommended way to install WiX v5+ (the classic
    wixNNN.exe Burn installer only ships WiX v3). Requires internet access to
    dot.net and the NuGet.org "wix" package feed.
#>

[CmdletBinding()]
param(
    [string]$DownloadFolder = "$env:TEMP\WixToolsetDotnetInstall"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}

try {
    # 1. Check if the wix global tool is already installed
    Write-Step "Checking if the WiX Toolset (dotnet tool) is already installed..."
    $existingWix = & dotnet tool list --global 2>$null | Select-String -Pattern '^\s*wix\s'
    if ($existingWix) {
        Write-Host "WiX Toolset is already installed: $existingWix" -ForegroundColor Yellow
        Write-Host "Exiting without reinstalling." -ForegroundColor Yellow
        return
    }
}
catch {
    # `dotnet` not found yet - continue, it will be installed below
}

try {
    # 2. Prepare the working folder
    Write-Step "Preparing temporary working folder ($DownloadFolder)..."
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = "SilentlyContinue"

    # 3. Ensure the .NET SDK is available
    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnetCmd) {
        Write-Step "Downloading .NET SDK installer script..."
        $dotnetInstallScript = Join-Path $DownloadFolder "dotnet-install.ps1"
        Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $dotnetInstallScript -UseBasicParsing

        Write-Step "Installing .NET SDK (LTS channel)..."
        & $dotnetInstallScript -Channel LTS -InstallDir "$env:LOCALAPPDATA\Microsoft\dotnet" -NoPath
        if ($LASTEXITCODE -ne 0) {
            throw ".NET SDK installation failed with exit code $LASTEXITCODE."
        }

        $env:Path = "$env:LOCALAPPDATA\Microsoft\dotnet;$env:Path"
        $env:DOTNET_ROOT = "$env:LOCALAPPDATA\Microsoft\dotnet"
        Write-Host ".NET SDK installed." -ForegroundColor Green
    }
    else {
        Write-Host ".NET SDK already present: $(& dotnet --version)" -ForegroundColor Green
    }

    $ProgressPreference = "Continue"

    # 4. Install the WiX Toolset global tool
    Write-Step "Installing WiX Toolset (dotnet tool install --global wix)..."
    & dotnet tool install --global wix
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet tool install failed with exit code $LASTEXITCODE."
    }
    Write-Host "Installation completed successfully." -ForegroundColor Green

    # 5. Make sure the dotnet global tools folder is on PATH for this session
    $toolsPath = Join-Path $env:USERPROFILE ".dotnet\tools"
    if (Test-Path $toolsPath) {
        $env:Path = "$toolsPath;$env:Path"
    }

    # 6. Verify the installation
    Write-Step "Verifying the installation..."
    $wixCmd = Get-Command wix -ErrorAction SilentlyContinue
    if ($wixCmd) {
        $installedVersion = & wix --version
        Write-Host "Success! WiX Toolset v$installedVersion installed." -ForegroundColor Green
    }
    else {
        Write-Host "wix tool installed, but not found in the current session's PATH. Open a new terminal to use the 'wix' command." -ForegroundColor Yellow
    }

    Write-Host "Done." -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

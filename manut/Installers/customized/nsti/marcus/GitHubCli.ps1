
<#
.SYNOPSIS
    Downloads and installs GitHub CLI (gh) for Windows (64-bit) 100% silently.

.DESCRIPTION
    Queries the GitHub API for the latest cli/cli release, downloads the
    official MSI installer, and runs the silent installation via msiexec
    (no windows, no clicks). Reports each step to the console.

.PARAMETER DownloadFolder
    Temporary folder where the installer will be downloaded.

.EXAMPLE
    .\GitHubCli.ps1
    Installs (or verifies) the latest GitHub CLI release.

.NOTES
    Run in a PowerShell session with Administrator privileges so the
    installation (which writes to Program Files and the registry) works without errors.
#>

[CmdletBinding()]
param(
    # Temporary folder where the installer will be downloaded
    [string]$DownloadFolder = "$env:TEMP\GitHubCliInstall"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}

try {
    # 1. Check if GitHub CLI is already installed
    Write-Step "Checking if GitHub CLI is already installed..."
    $existingGh = Get-Command gh -ErrorAction SilentlyContinue
    if ($existingGh) {
        $version = & gh --version
        Write-Host "GitHub CLI is already installed: $version" -ForegroundColor Yellow
        Write-Host "Exiting without reinstalling. Use -Force removing this check if you want to reinstall." -ForegroundColor Yellow
        return
    }

    # 2. Prepare the download folder
    Write-Step "Preparing temporary download folder ($DownloadFolder)..."
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }

    # 3. Discover the latest version via the GitHub API
    Write-Step "Querying the latest GitHub CLI version..."
    $apiUrl = "https://api.github.com/repos/cli/cli/releases/latest"
    $headers = @{ "User-Agent" = "installGitHubCli-script" }
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers

    # Look for the 64-bit MSI installer asset (e.g. gh_2.60.1_windows_amd64.msi)
    $asset = $release.assets | Where-Object { $_.name -match '^gh_.*_windows_amd64\.msi$' } | Select-Object -First 1

    if (-not $asset) {
        throw "Could not find the 64-bit MSI installer in the latest release."
    }

    $downloadUrl   = $asset.browser_download_url
    $installerPath = Join-Path $DownloadFolder $asset.name

    Write-Host "Version found: $($release.tag_name)" -ForegroundColor Green

    # 4. Download the installer
    Write-Step "Downloading... ($($asset.name))"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

    if (-not (Test-Path $installerPath)) {
        throw "Failed to download the installer."
    }
    Write-Host "Download complete: $installerPath" -ForegroundColor Green

    # 5. Install silently via msiexec
    #   /i       -> install
    #   /qn      -> no UI (quiet, no windows)
    #   /norestart -> does not restart the computer
    #   /log     -> generates an installation log
    $logPath = Join-Path $DownloadFolder "gh-install.log"

    Write-Step "Installing..."
    $installArgs = @(
        "/i", "`"$installerPath`"",
        "/qn",
        "/norestart",
        "/log", "`"$logPath`""
    )

    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        throw "The installation failed with exit code $($process.ExitCode). See the log at $logPath"
    }

    Write-Host "Installation completed successfully." -ForegroundColor Green

    # 6. Update the current session's PATH and verify the installation
    Write-Step "Verifying the installation..."
    $ghDefaultPath = "$env:ProgramFiles\GitHub CLI"
    if (Test-Path $ghDefaultPath) {
        $env:Path = "$ghDefaultPath;$env:Path"
    }

    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($ghCmd) {
        $installedVersion = & gh --version
        Write-Host "Success! $installedVersion" -ForegroundColor Green
    }
    else {
        Write-Host "GitHub CLI installed, but not found in the current session's PATH. Open a new terminal to use the 'gh' command." -ForegroundColor Yellow
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

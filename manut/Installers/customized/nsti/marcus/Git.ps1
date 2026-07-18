
<#
.SYNOPSIS
    Downloads and installs Git for Windows (64-bit) 100% silently.

.DESCRIPTION
    Queries the GitHub API for the latest Git for Windows release,
    downloads the official installer, and runs the silent installation
    (no windows, no clicks). Reports each step to the console.

.NOTES
    Run in a PowerShell session with Administrator privileges so the
    installation (which writes to Program Files and the registry) works without errors.
#>

[CmdletBinding()]
param(
    # Temporary folder where the installer will be downloaded
    [string]$DownloadFolder = "$env:TEMP\GitInstall"
)
 
$ErrorActionPreference = "Stop"
 
function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}
 
try {
    # 1. Check if Git is already installed
    Write-Step "Checking if Git is already installed..."
    $existingGit = Get-Command git -ErrorAction SilentlyContinue
    if ($existingGit) {
        $version = & git --version
        Write-Host "Git is already installed: $version" -ForegroundColor Yellow
        Write-Host "Exiting without reinstalling. Use -Force removing this check if you want to reinstall." -ForegroundColor Yellow
        return
    }

    # 2. Prepare the download folder
    Write-Step "Preparing temporary download folder ($DownloadFolder)..."
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }

    # 3. Discover the latest version via the GitHub API
    Write-Step "Querying the latest Git for Windows version..."
    $apiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
    $headers = @{ "User-Agent" = "installGit-script" }
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers

    # Look for the 64-bit installer asset (e.g. Git-2.46.0-64-bit.exe)
    $asset = $release.assets | Where-Object { $_.name -match '^Git-.*-64-bit\.exe$' } | Select-Object -First 1

    if (-not $asset) {
        throw "Could not find the 64-bit installer in the latest release."
    }

    $downloadUrl  = $asset.browser_download_url
    $installerPath = Join-Path $DownloadFolder $asset.name

    Write-Host "Version found: $($release.tag_name)" -ForegroundColor Green

    # 4. Download the installer
    Write-Step "Downloading... ($($asset.name))"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing

    if (-not (Test-Path $installerPath)) {
        throw "Failed to download the installer."
    }
    Write-Host "Download complete: $installerPath" -ForegroundColor Green

    # 5. Install silently
    # The Git for Windows installer uses Inno Setup, so it accepts these parameters:
    #   /VERYSILENT        -> no visible window
    #   /NORESTART         -> does not restart the computer
    #   /NOCANCEL          -> prevents cancellation
    #   /SP-                -> does not show the initial "This will install..." prompt
    #   /SUPPRESSMSGBOXES  -> suppresses message boxes
    #   /CLOSEAPPLICATIONS -> closes apps that could block the installation
    #   /LOG               -> generates an installation log
    $logPath = Join-Path $DownloadFolder "git-install.log"

    Write-Step "Installing..."
    $installArgs = @(
        "/VERYSILENT",
        "/NORESTART",
        "/NOCANCEL",
        "/SP-",
        "/SUPPRESSMSGBOXES",
        "/CLOSEAPPLICATIONS",
        "/LOG=`"$logPath`""
    )

    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        throw "The installation failed with exit code $($process.ExitCode). See the log at $logPath"
    }

    Write-Host "Installation completed successfully." -ForegroundColor Green

    # 6. Update the current session's PATH and verify the installation
    Write-Step "Verifying the installation..."
    $gitDefaultPath = "$env:ProgramFiles\Git\cmd"
    if (Test-Path $gitDefaultPath) {
        $env:Path = "$gitDefaultPath;$env:Path"
    }

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $installedVersion = & git --version
        Write-Host "Success! $installedVersion" -ForegroundColor Green
    }
    else {
        Write-Host "Git installed, but not found in the current session's PATH. Open a new terminal to use the 'git' command." -ForegroundColor Yellow
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
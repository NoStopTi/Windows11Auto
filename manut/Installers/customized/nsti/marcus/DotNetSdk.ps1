<#
.SYNOPSIS
    Downloads and installs the .NET SDK (64-bit) for Windows, 100% silently.

.DESCRIPTION
    Required to build, run and publish the "Conductor" solution
    (D:\Projects\conductor\Conductor.Ws\Conductor.Ws.sln). All four projects
    in that solution (Conductor.Ws, Conductor.Updater, Conductor.Shared,
    Conductor.Session) target net9.0-windows / win-x64, so the .NET 9 SDK
    must be present on the machine to restore, build or publish them.

    - Queries the official .NET release metadata (releases-index.json ->
      releases.json for the requested channel) to find the latest SDK build,
      the same way Microsoft's own tooling resolves "latest".
    - Downloads the official win-x64 installer (.exe) from
      builds.dotnet.microsoft.com.
    - Runs the silent installation (/install /quiet /norestart - no windows,
      no clicks).
    - Reports each step to the console.

    NOTE: The NuGet packages referenced by the solution
    (Microsoft.Extensions.Hosting.WindowsServices, Microsoft.Extensions.Http,
    System.Management, System.ServiceProcess.ServiceController) are restored
    automatically by "dotnet restore/build/publish" once the SDK is
    installed - they don't need a separate installer, just internet access
    to nuget.org.

.NOTES
    Run in a PowerShell session with Administrator privileges so the
    installation (which writes to Program Files and the registry) works without errors.
    Source: https://learn.microsoft.com/en-us/dotnet/core/install/windows
#>

[CmdletBinding()]
param(
    # .NET channel to install. Defaults to 9.0, matching the Conductor
    # project's TargetFramework (net9.0-windows).
    [string]$Channel = "9.0",

    # Temporary folder where the installer will be downloaded
    [string]$DownloadFolder = "$env:TEMP\DotNetSdkInstall",

    # Reinstall/repair even if a matching SDK is already present
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}

try {
    # 1. Check if a matching .NET SDK is already installed
    Write-Step "Checking if the .NET $Channel SDK is already installed..."
    $existingDotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($existingDotnet -and -not $Force) {
        $installedSdks = & dotnet --list-sdks 2>$null
        $match = $installedSdks | Where-Object { $_ -match "^$([regex]::Escape($Channel))\." }
        if ($match) {
            Write-Host "The .NET $Channel SDK is already installed: $match" -ForegroundColor Yellow
            Write-Host "Exiting without reinstalling. Use -Force to reinstall/repair." -ForegroundColor Yellow
            return
        }
    }

    # 2. Prepare the download folder
    Write-Step "Preparing temporary download folder ($DownloadFolder)..."
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = "SilentlyContinue"

    # 3. Discover the releases.json for the requested channel
    Write-Step "Querying the .NET release index for channel $Channel..."
    $releasesIndex = Invoke-RestMethod -Uri "https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json" -UseBasicParsing
    $channelEntry = $releasesIndex.'releases-index' | Where-Object { $_.'channel-version' -eq $Channel } | Select-Object -First 1

    if (-not $channelEntry) {
        throw "Could not find channel $Channel in the .NET release index."
    }

    # 4. Discover the latest SDK build for that channel and the win-x64 installer URL
    Write-Step "Querying the latest .NET $Channel SDK build..."
    $releases = Invoke-RestMethod -Uri $channelEntry.'releases.json' -UseBasicParsing
    $latestSdk = $releases.releases[0].sdk

    $asset = $latestSdk.files | Where-Object { $_.name -eq "dotnet-sdk-win-x64.exe" } | Select-Object -First 1
    if (-not $asset) {
        throw "Could not find the win-x64 SDK installer in the latest release."
    }

    $downloadUrl   = $asset.url
    $installerPath = Join-Path $DownloadFolder "dotnet-sdk-$($latestSdk.version)-win-x64.exe"

    Write-Host "Version found: .NET SDK $($latestSdk.version)" -ForegroundColor Green

    # 5. Download the installer
    Write-Step "Downloading... (dotnet-sdk-$($latestSdk.version)-win-x64.exe)"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
    $ProgressPreference = "Continue"

    if (-not (Test-Path $installerPath)) {
        throw "Failed to download the installer."
    }
    Write-Host "Download complete: $installerPath" -ForegroundColor Green

    # 6. Install silently
    # The .NET installer is a Burn bundle and accepts these parameters:
    #   /install    -> installs .NET
    #   /quiet      -> no UI, no prompts
    #   /norestart  -> does not restart the computer
    #   /log        -> generates an installation log
    $logPath = Join-Path $DownloadFolder "dotnet-sdk-install.log"

    Write-Step "Installing..."
    $installArgs = @(
        "/install",
        "/quiet",
        "/norestart",
        "/log", "`"$logPath`""
    )

    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru

    # The installer returns 0 for success and 3010 when a restart is required.
    if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 3010) {
        throw "The installation failed with exit code $($process.ExitCode). See the log at $logPath"
    }

    if ($process.ExitCode -eq 3010) {
        Write-Host "Installation completed successfully. A restart is required to finish." -ForegroundColor Yellow
    }
    else {
        Write-Host "Installation completed successfully." -ForegroundColor Green
    }

    # 7. Update the current session's PATH and verify the installation
    Write-Step "Verifying the installation..."
    $dotnetDefaultPath = "$env:ProgramFiles\dotnet"
    if (Test-Path $dotnetDefaultPath) {
        $env:Path = "$dotnetDefaultPath;$env:Path"
    }

    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnetCmd) {
        Write-Host "Success! Installed SDKs:" -ForegroundColor Green
        & dotnet --list-sdks
    }
    else {
        Write-Host ".NET installed, but not found in the current session's PATH. Open a new terminal to use the 'dotnet' command." -ForegroundColor Yellow
    }

    # 8. Optional cleanup of the downloaded installer
    Write-Step "Cleaning up temporary files..."
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue

    Write-Host "Done. You can now build the Conductor solution with:" -ForegroundColor Cyan
    Write-Host "  dotnet build D:\Projects\conductor\Conductor.Ws\Conductor.Ws.sln" -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

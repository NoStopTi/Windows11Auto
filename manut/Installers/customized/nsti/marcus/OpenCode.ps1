<#
.SYNOPSIS
    Installs OpenCode (CLI) for the current user on Windows 100% silently.

.DESCRIPTION
    Native PowerShell port of the official installer
    (curl -fsSL https://opencode.ai/v2/install | bash), which is a bash script
    and therefore cannot run from machines.json on a plain Windows machine.

    Steps (same as the official script):
      1. Detects whether the CPU supports AVX2 (otherwise uses the "-baseline" build).
      2. Resolves the latest version/package from https://opencode.ai/update/api/latest/cli/npm
         (or uses -Version when provided).
      3. Downloads the cli-windows-x64[-baseline] tarball from the npm registry.
      4. Extracts package\bin\opencode.exe to %USERPROFILE%\.opencode\bin.
      5. Creates the legacy "opencode2.cmd" shim.
      6. Appends the install folder to the USER Path (idempotent, keeps existing entries).

.PARAMETER Version
    Specific version to install (e.g. 2.0.18). Defaults to the latest release.

.PARAMETER InstallDir
    Destination folder for opencode.exe. Defaults to %USERPROFILE%\.opencode\bin
    (same location used by the official installer).

.PARAMETER DownloadFolder
    Temporary folder used for the download and extraction.

.PARAMETER NoModifyPath
    Does not change the user's Path environment variable.

.EXAMPLE
    .\OpenCode.ps1
    Installs (or updates to) the latest OpenCode release.

.EXAMPLE
    .\OpenCode.ps1 -Version 2.0.18 -NoModifyPath
    Installs a specific version without touching the Path.

.NOTES
    Per-user installation: no Administrator privileges required.
    Requires tar.exe (bundled with Windows 10 1803+ / Windows 11).
#>

[CmdletBinding()]
param(
    [string]$Version,
    [string]$InstallDir = "$env:USERPROFILE\.opencode\bin",
    [string]$DownloadFolder = "$env:TEMP\OpenCodeInstall",
    [switch]$NoModifyPath
)

$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 may default to protocols the registry does not accept
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}

function Test-Avx2Support {
    # PF_AVX2_INSTRUCTIONS_AVAILABLE = 40. Same check the official script does;
    # CPUs without AVX2 crash with the regular build, so they need the baseline one.
    Add-Type -Namespace Win32 -Name Kernel32 -MemberDefinition @'
[DllImport("kernel32.dll")]
public static extern bool IsProcessorFeaturePresent(int ProcessorFeature);
'@ -ErrorAction SilentlyContinue
    return [Win32.Kernel32]::IsProcessorFeaturePresent(40)
}

try {
    # 1. Detect architecture (the official installer only ships windows-x64)
    Write-Step "Detecting platform..."
    if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
        throw "Unsupported architecture: only windows-x64 is provided by OpenCode."
    }

    $target = "windows-x64"
    if (-not (Test-Avx2Support)) {
        $target = "$target-baseline"
    }
    Write-Host "Target: $target" -ForegroundColor Green

    # Fall back to the System32 copy: a broken/trimmed Path must not block the install
    $tarExe = (Get-Command tar.exe -ErrorAction SilentlyContinue).Source
    if (-not $tarExe) {
        $tarExe = Join-Path $env:SystemRoot "System32\tar.exe"
    }
    if (-not (Test-Path $tarExe)) {
        throw "'tar.exe' is required but was not found."
    }

    # 2. Resolve version and package scope
    $packageScope = "@opencode"
    if ([string]::IsNullOrWhiteSpace($Version)) {
        Write-Step "Querying the latest OpenCode version..."
        $metadata = Invoke-RestMethod -Uri "https://opencode.ai/update/api/latest/cli/npm" -UseBasicParsing
        $Version = $metadata.version
        if (-not $Version -or -not $metadata.metadata.package) {
            throw "Failed to fetch version information."
        }
        # "@opencode/cli" -> "@opencode"
        $packageScope = $metadata.metadata.package -replace '/cli$', ''
    }
    else {
        $Version = $Version.TrimStart('v')
    }
    Write-Host "Version: $Version" -ForegroundColor Green

    # 3. Confirm the package exists in the npm registry (older versions live under @opencode-ai)
    $packageName = "$packageScope/cli-$target"
    $registryUrl = "https://registry.npmjs.org/$($packageScope)%2fcli-$target/$Version"
    try {
        Invoke-RestMethod -Uri $registryUrl -UseBasicParsing | Out-Null
    }
    catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            throw "Version $Version is not available for $target."
        }
        throw
    }

    # 4. Download the tarball
    $fileName = "cli-$target-$Version.tgz"
    $downloadUrl = "https://registry.npmjs.org/$packageName/-/$fileName"
    $tarballPath = Join-Path $DownloadFolder $fileName

    Write-Step "Preparing temporary download folder ($DownloadFolder)..."
    if (Test-Path $DownloadFolder) {
        Remove-Item -Path $DownloadFolder -Recurse -Force
    }
    New-Item -ItemType Directory -Path $DownloadFolder | Out-Null

    Write-Step "Downloading ($fileName)..."
    $ProgressPreference = "SilentlyContinue"  # speeds up Invoke-WebRequest
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tarballPath -UseBasicParsing
    $ProgressPreference = "Continue"

    if (-not (Test-Path $tarballPath)) {
        throw "Failed to download the package."
    }

    # 5. Extract and copy the binary
    Write-Step "Installing to $InstallDir..."
    & $tarExe -xzf $tarballPath -C $DownloadFolder
    if ($LASTEXITCODE -ne 0) {
        throw "tar.exe failed with exit code $LASTEXITCODE."
    }

    $extractedBinary = Join-Path $DownloadFolder "package\bin\opencode.exe"
    if (-not (Test-Path $extractedBinary)) {
        throw "opencode.exe was not found inside the downloaded package."
    }

    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    # A running opencode.exe locks the file; surface a clear error instead of a generic one
    try {
        Copy-Item -Path $extractedBinary -Destination (Join-Path $InstallDir "opencode.exe") -Force
    }
    catch {
        throw "Could not overwrite opencode.exe (is OpenCode running?): $($_.Exception.Message)"
    }

    # Legacy shim kept for compatibility with older clients that call "opencode2"
    $shimPath = Join-Path $InstallDir "opencode2.cmd"
    Set-Content -Path $shimPath -Encoding ASCII -Value @(
        "@echo off",
        "`"%~dp0opencode.exe`" %*",
        "exit /b %errorlevel%"
    )

    # 6. Add the install folder to the USER Path without discarding existing entries
    if (-not $NoModifyPath) {
        Write-Step "Updating user Path..."
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $entries = @()
        if ($userPath) {
            $entries = $userPath.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
        }

        if ($entries -notcontains $InstallDir) {
            $newPath = (($entries + $InstallDir) -join ';')
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            Write-Host "Added $InstallDir to the user Path." -ForegroundColor Green
        }
        else {
            Write-Host "$InstallDir is already in the user Path." -ForegroundColor Yellow
        }
    }

    # Make it available to this session too (for the verification below and for callers)
    if (($env:Path.Split(';')) -notcontains $InstallDir) {
        $env:Path = "$InstallDir;$env:Path"
    }

    # 7. Verify
    Write-Step "Verifying the installation..."
    $installedVersion = & (Join-Path $InstallDir "opencode.exe") --version
    if ($LASTEXITCODE -ne 0) {
        throw "opencode --version failed with exit code $LASTEXITCODE."
    }
    Write-Host "Success! OpenCode $installedVersion" -ForegroundColor Green

    # 8. Cleanup
    Write-Step "Cleaning up temporary files..."
    Remove-Item -Path $DownloadFolder -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Done." -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

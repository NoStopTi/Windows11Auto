<#
.SYNOPSIS
    Downloads the official Ubuntu WSL root filesystem image (this version
    or newer, if one is already published) and imports it into WSL as a
    custom distribution, provisioning a non-root default user, 100%
    silently and non-interactively.

.DESCRIPTION
    Resolves the current Ubuntu 26.04.x WSL image from Canonical's own
    download server (releases.ubuntu.com), which keeps a "<series>/" alias
    directory (e.g. "26.04/") permanently pointing at the latest published
    point release for that series -- so this always downloads
    ubuntu-26.04.1-wsl-amd64.wsl or a newer respin of the same series
    without hardcoding future version numbers. The download is verified
    against the SHA256SUMS file published in the same directory before use.

    The image is then imported as a new WSL distribution via:
        wsl --import <DistroName> <InstallPath> <DownloadedFile> --version 2

    A distribution imported this way (unlike one installed from the
    Microsoft Store) boots straight in as root with no configured user, so
    this script also provisions one:
      1. Creates the user (the non-interactive 'useradd' primitive is used
         instead of 'adduser', which is Debian/Ubuntu's interactive
         front-end and would block this script waiting for prompts).
      2. Sets its password via 'chpasswd', piped over stdin so the
         password is never exposed as a process argument inside the
         distro.
      3. Marks it as the distribution's default login user.

    For step 3, there is no per-distro launcher executable (e.g.
    "UbuntuCustom.exe config --default-user ...") for a distribution
    registered via 'wsl --import' -- that convenience .exe is only
    generated for distributions installed from the Microsoft Store. The
    real, current equivalent used here is:
        wsl --manage <DistroName> --set-default-user <Username>
    On older WSL releases that predate that flag, this script falls back
    to writing "[user]\ndefault=<Username>" to /etc/wsl.conf inside the
    distribution and terminating it so the setting is picked up on the
    next launch.

    The script is idempotent and safe to rerun: if the distribution is
    already imported, the download/import step is skipped, but the user
    provisioning steps are still (re)applied, so a rerun can pick up from
    a partially completed previous run.

.PARAMETER DistroName
    Name under which the distribution is registered in WSL.

.PARAMETER InstallPath
    Folder where the distribution's virtual disk is stored.

.PARAMETER Username
    Name of the non-root user created inside the distribution and set as
    its default login user.

.PARAMETER Password
    Password assigned to $Username via chpasswd.

.PARAMETER MinimumVersion
    Baseline Ubuntu version ("YY.MM.patch") to look for; a newer point
    release of the same "YY.MM" series is used automatically if Canonical
    has already published one.

.PARAMETER WslVersion
    WSL engine version (1 or 2) passed to 'wsl --import --version'.

.PARAMETER DownloadFolder
    Temporary folder where the .wsl image is downloaded before import.

.EXAMPLE
    .\WslUbuntuCustom.ps1
    Imports (or verifies) 'UbuntuCustom' with user 'marcus' as its default
    user.

.NOTES
    Run in a PowerShell session with Administrator privileges: enabling
    the Microsoft-Windows-Subsystem-Linux and VirtualMachinePlatform
    Windows optional features (when not already enabled) is a
    system-wide (HKLM) change.

    $Password defaults to a short, non-secret value on purpose, as
    explicitly requested for this internal/dev provisioning flow -- pass
    -Password with a stronger value for anything beyond that use case.
#>

[CmdletBinding()]
param(
    # Name under which the distribution is registered in WSL
    [string]$DistroName = "UbuntuCustom",

    # Folder where the distribution's virtual disk is stored
    [string]$InstallPath = "C:\WSL\UbuntuCustom",

    # Non-root user created inside the distribution
    [string]$Username = "marcus",

    # Password assigned to $Username
    [string]$Password = "123",

    # Baseline Ubuntu version; a newer point release is used automatically if available
    [string]$MinimumVersion = "26.04.1",

    # WSL engine version passed to 'wsl --import --version'
    [int]$WslVersion = 2,

    # Temporary folder where the .wsl image is downloaded
    [string]$DownloadFolder = "$env:TEMP\UbuntuCustomWslInstall"
)

$ErrorActionPreference = "Stop"

# On PowerShell 7.3+, a non-zero exit code from a native command (wsl.exe
# included) is promoted to a terminating error under $ErrorActionPreference
# = "Stop". Several wsl.exe calls below (e.g. checking whether a user
# already exists) legitimately exit non-zero as a normal, expected
# outcome, not an error -- so that promotion is disabled here.
$PSNativeCommandUseErrorActionPreference = $false

function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}

function Test-IsAdministrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Wsl {
    param([Parameter(Mandatory)] [string[]]$ArgumentList)

    # wsl.exe emits UTF-16LE text; when its stdout/stderr are redirected
    # (as opposed to a real console) PowerShell can capture embedded NUL
    # bytes between characters, so they are stripped before the text is
    # inspected or logged.
    $rawOutput = & wsl.exe @ArgumentList 2>&1
    $output    = $rawOutput | ForEach-Object { ([string]$_) -replace "`0", "" }

    return [PSCustomObject]@{
        Output   = $output
        ExitCode = $LASTEXITCODE
    }
}

function Enable-WslPrerequisites {
    # Returns $true if a restart is required before WSL 2 distributions can actually run.
    $features      = @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")
    $restartNeeded = $false

    foreach ($feature in $features) {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue).State
        if ($state -ne "Enabled") {
            Write-Step "Enabling Windows optional feature '$feature'..."
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
            if ($result.RestartNeeded) {
                $restartNeeded = $true
            }
        }
    }

    return $restartNeeded
}

function Test-DistroImported {
    param([Parameter(Mandatory)] [string]$Name)

    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        return $false
    }

    $result = Invoke-Wsl -ArgumentList @("--list", "--quiet")
    if ($result.ExitCode -ne 0) {
        # Non-zero here means "no distributions registered yet", not a script failure.
        return $false
    }

    $registered = $result.Output | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
    return [bool]($registered -contains $Name)
}

function Test-DistroUserExists {
    param(
        [Parameter(Mandatory)] [string]$Distro,
        [Parameter(Mandatory)] [string]$User
    )

    $result = Invoke-Wsl -ArgumentList @("-d", $Distro, "-u", "root", "--", "id", "-u", $User)
    return ($result.ExitCode -eq 0)
}

function Get-UbuntuWslAsset {
    param([Parameter(Mandatory)] [string]$MinimumVersion)

    $versionMatch = [regex]::Match($MinimumVersion, '^(\d+)\.(\d+)(?:\.(\d+))?$')
    if (-not $versionMatch.Success) {
        throw "MinimumVersion '$MinimumVersion' is not in the expected 'YY.MM' or 'YY.MM.patch' format."
    }
    $series = "$($versionMatch.Groups[1].Value).$($versionMatch.Groups[2].Value)"

    # releases.ubuntu.com keeps a "<series>/" alias (e.g. "26.04/") that
    # always points at the directory of the current, latest point release
    # for that series -- including every still-published .wsl respin -- so
    # scraping it is enough to always resolve to "this version or newer"
    # without hardcoding future patch numbers.
    $baseUrl  = "https://releases.ubuntu.com/$series/"
    $fileName = $null

    try {
        $index       = Invoke-WebRequest -Uri $baseUrl -UseBasicParsing
        $pattern     = "ubuntu-$([regex]::Escape($series))(?:\.(\d+))?-wsl-amd64\.wsl"
        $wslFileHits = [regex]::Matches($index.Content, $pattern)

        if ($wslFileHits.Count -gt 0) {
            $highestPatch = ($wslFileHits | ForEach-Object {
                if ($_.Groups[1].Success) { [int]$_.Groups[1].Value } else { 0 }
            } | Measure-Object -Maximum).Maximum

            $fileName = if ($highestPatch -gt 0) { "ubuntu-$series.$highestPatch-wsl-amd64.wsl" } else { "ubuntu-$series-wsl-amd64.wsl" }
        }
    }
    catch {
        Write-Host "Could not browse $baseUrl ($($_.Exception.Message)); falling back to the exact requested version." -ForegroundColor Yellow
    }

    if (-not $fileName) {
        $baseUrl  = "https://releases.ubuntu.com/$MinimumVersion/"
        $fileName = "ubuntu-$MinimumVersion-wsl-amd64.wsl"
    }

    return [PSCustomObject]@{
        BaseUrl     = $baseUrl
        FileName    = $fileName
        DownloadUrl = "$baseUrl$fileName"
    }
}

function Get-UbuntuWslChecksum {
    param(
        [Parameter(Mandatory)] [string]$BaseUrl,
        [Parameter(Mandatory)] [string]$FileName
    )

    $sums  = (Invoke-WebRequest -Uri "${BaseUrl}SHA256SUMS" -UseBasicParsing).Content
    $match = [regex]::Match($sums, "(?m)^([0-9a-fA-F]{64})\s+\*?$([regex]::Escape($FileName))\s*$")

    if (-not $match.Success) {
        throw "Could not find a SHA256 checksum for $FileName in ${BaseUrl}SHA256SUMS."
    }

    return $match.Groups[1].Value.ToUpper()
}

try {
    # 1. Enabling Windows optional features / importing into C:\WSL requires elevation
    Write-Step "Checking for Administrator privileges..."
    if (-not (Test-IsAdministrator)) {
        throw "This script must be run in a PowerShell session with Administrator privileges (WSL setup enables system-wide Windows optional features)."
    }

    # 2. Make sure the WSL platform itself can actually run before doing anything else
    Write-Step "Checking WSL/Virtual Machine Platform Windows optional features..."
    if (Enable-WslPrerequisites) {
        throw "The WSL and/or Virtual Machine Platform Windows features were just enabled for the first time and require a restart before they become active. Restart the computer and rerun this script."
    }

    $distroAlreadyImported = Test-DistroImported -Name $DistroName

    if ($distroAlreadyImported) {
        Write-Host "'$DistroName' is already imported on WSL." -ForegroundColor Yellow
        Write-Host "Skipping download/import; only the user setup below will be (re)applied." -ForegroundColor Yellow
    }
    else {
        # 3. Resolve the current Ubuntu WSL image (this version or newer)
        Write-Step "Resolving the Ubuntu WSL image (>= $MinimumVersion)..."
        $asset = Get-UbuntuWslAsset -MinimumVersion $MinimumVersion
        Write-Host "Resolved asset: $($asset.FileName)" -ForegroundColor Green

        # 4. Download the image
        Write-Step "Preparing download folder ($DownloadFolder)..."
        if (-not (Test-Path $DownloadFolder)) {
            New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
        }
        $imagePath = Join-Path $DownloadFolder $asset.FileName

        if (Test-Path $imagePath) {
            Write-Host "Reusing previously downloaded file: $imagePath" -ForegroundColor Yellow
        }
        else {
            Write-Step "Downloading $($asset.FileName) (a few hundred MB, this can take a while)..."
            Invoke-WebRequest -Uri $asset.DownloadUrl -OutFile $imagePath -UseBasicParsing
        }

        if (-not (Test-Path $imagePath)) {
            throw "Failed to download the WSL image."
        }

        # 5. Verify integrity against the checksum published by the same server
        Write-Step "Verifying integrity (SHA256)..."
        $expectedHash = Get-UbuntuWslChecksum -BaseUrl $asset.BaseUrl -FileName $asset.FileName
        $actualHash   = (Get-FileHash -Path $imagePath -Algorithm SHA256).Hash
        if ($actualHash -ne $expectedHash) {
            Remove-Item -Path $imagePath -Force -ErrorAction SilentlyContinue
            throw "SHA256 mismatch: expected $expectedHash, got $actualHash. Aborting import of a possibly corrupted/tampered file."
        }
        Write-Host "Checksum verified." -ForegroundColor Green

        # 6. Import the distribution
        Write-Step "Preparing install location ($InstallPath)..."
        if (-not (Test-Path $InstallPath)) {
            New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        }

        Write-Step "Importing '$DistroName' into WSL (wsl --import $DistroName $InstallPath ... --version $WslVersion)..."
        $importResult = Invoke-Wsl -ArgumentList @("--import", $DistroName, $InstallPath, $imagePath, "--version", "$WslVersion")
        if ($importResult.Output) {
            Write-Host ($importResult.Output -join [Environment]::NewLine)
        }
        if ($importResult.ExitCode -ne 0) {
            throw "wsl --import failed with exit code $($importResult.ExitCode)."
        }
        Write-Host "Import completed successfully." -ForegroundColor Green

        # 7. Cleanup of the downloaded image
        Write-Step "Cleaning up the downloaded image..."
        Remove-Item -Path $imagePath -Force -ErrorAction SilentlyContinue
    }

    # 8. Create the default user (idempotent)
    Write-Step "Checking if user '$Username' already exists inside '$DistroName'..."
    if (Test-DistroUserExists -Distro $DistroName -User $Username) {
        Write-Host "User '$Username' already exists." -ForegroundColor Yellow
    }
    else {
        Write-Step "Creating user '$Username' (non-interactive equivalent of 'adduser $Username')..."
        $userResult = Invoke-Wsl -ArgumentList @("-d", $DistroName, "-u", "root", "--", "useradd", "--create-home", "--shell", "/bin/bash", $Username)
        if ($userResult.ExitCode -ne 0) {
            throw "Failed to create user '$Username' inside '$DistroName' (exit code $($userResult.ExitCode))."
        }
        Write-Host "User '$Username' created." -ForegroundColor Green
    }

    # 9. Set the password (idempotent, applied every run as requested)
    Write-Step "Setting the password for '$Username'..."
    "$($Username):$($Password)" | & wsl.exe -d $DistroName -u root -- chpasswd
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set the password for '$Username' (exit code $LASTEXITCODE)."
    }
    Write-Host "Password set." -ForegroundColor Green

    # 10. Set the default user
    Write-Step "Setting '$Username' as the default user for '$DistroName'..."
    $manageResult = Invoke-Wsl -ArgumentList @("--manage", $DistroName, "--set-default-user", $Username)
    if ($manageResult.ExitCode -ne 0) {
        Write-Host "'wsl --manage --set-default-user' is not available on this WSL version; falling back to /etc/wsl.conf." -ForegroundColor Yellow
        $wslConfResult = Invoke-Wsl -ArgumentList @("-d", $DistroName, "-u", "root", "--", "bash", "-c", "printf '[user]\ndefault=%s\n' '$Username' > /etc/wsl.conf")
        if ($wslConfResult.ExitCode -ne 0) {
            throw "Failed to write /etc/wsl.conf inside '$DistroName' (exit code $($wslConfResult.ExitCode))."
        }
        # wsl.conf changes only take effect once the distribution's instance
        # has fully stopped and is relaunched.
        Invoke-Wsl -ArgumentList @("--terminate", $DistroName) | Out-Null
    }
    Write-Host "Default user set to '$Username'." -ForegroundColor Green

    # 11. Verify
    Write-Step "Verifying the installation..."
    if (Test-DistroImported -Name $DistroName) {
        Write-Host "'$DistroName' is registered on WSL." -ForegroundColor Green
    }
    else {
        Write-Host "'$DistroName' was not found registered; something went wrong." -ForegroundColor Yellow
    }

    $whoamiResult = Invoke-Wsl -ArgumentList @("-d", $DistroName, "--", "whoami")
    $defaultUser  = $whoamiResult.Output | Select-Object -First 1
    if ($defaultUser -and $defaultUser.Trim() -eq $Username) {
        Write-Host "Success! Default user confirmed as '$Username'." -ForegroundColor Green
    }
    else {
        Write-Host "Could not confirm the default user (got: '$defaultUser')." -ForegroundColor Yellow
    }

    Write-Host "Done." -ForegroundColor Cyan
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

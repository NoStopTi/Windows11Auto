$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Status([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Cyan) {
    Write-Host "[Node.js] $Message" -ForegroundColor $Color
}

function Get-Version([string]$Command) {
    try { return ((& $Command --version 2>$null) | Select-Object -First 1).Trim().TrimStart('v') }
    catch { return $null }
}

try {
    Write-Status 'Checking for the latest LTS version...'
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 740 }

    $remoteVersion = $latest.version.TrimStart('v')
    $localVersion = Get-Version 'node'
    if ($localVersion -and ([version]$localVersion -ge [version]$remoteVersion)) { exit 0 }
    if ($localVersion -and ([version]$localVersion -ge [version]$remoteVersion)) {
        Write-Status "Already current (v$localVersion)." Green
        exit 0
    }

    $msiPath = Join-Path $env:TEMP "node-$remoteVersion-x64.msi"
    $uri = "https://nodejs.org/dist/$($latest.version)/node-$($latest.version)-x64.msi"
    Write-Status "Downloading Node.js v$remoteVersion..." Yellow
    Invoke-WebRequest -Uri $uri -OutFile $msiPath

    $signature = Get-AuthenticodeSignature -FilePath $msiPath
    if ($signature.Status -ne 'Valid') { Remove-Item -LiteralPath $msiPath -Force; exit 1 }

    Write-Status "Installing Node.js v$remoteVersion..." Yellow
    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', "`"$msiPath`"", '/qn', '/norestart') -Wait -PassThru -WindowStyle Hidden
    Remove-Item -LiteralPath $msiPath -Force -ErrorAction SilentlyContinue
    if ($process.ExitCode -notin 0, 3010) { exit $process.ExitCode }
    Write-Status "Finished. Node.js v$remoteVersion is installed." Green
    exit 0
}
catch { exit 1 }
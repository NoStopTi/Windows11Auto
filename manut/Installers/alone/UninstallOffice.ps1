<#
.SYNOPSIS
    Fully silent, non-interactive removal of Microsoft Office (Click-to-Run / MSI),
    including Office LTSC Standard 2021, leftovers, licenses and the activation wizard.

.NOTES
    Self-elevates when not running as administrator. Never prompts the user.
    Log: %ProgramData%\OfficeUninstall\uninstall.log
#>

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
$ConfirmPreference     = 'None'

# ---------------------------------------------------------------- self-elevation
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -Wait `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    exit $LASTEXITCODE
}

# ---------------------------------------------------------------- logging
$logDir  = Join-Path $env:ProgramData 'OfficeUninstall'
$logFile = Join-Path $logDir 'uninstall.log'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

function Write-Log {
    param([string] $Message, [string] $Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function Remove-PathSafe {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    try {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        Write-Log "Removed: $Path"
    }
    catch {
        # Fallback for locked/ACL-protected folders
        cmd.exe /c "takeown /f `"$Path`" /r /d y >nul 2>&1 & icacls `"$Path`" /grant administrators:F /t >nul 2>&1 & rd /s /q `"$Path`"" | Out-Null
        if (Test-Path -LiteralPath $Path) { Write-Log "Could not remove: $Path" 'WARN' }
        else { Write-Log "Removed (forced): $Path" }
    }
}

Write-Log '=== Office uninstall started ==='

# ---------------------------------------------------------------- 1. stop Office processes and services
$processNames = @(
    'WINWORD', 'EXCEL', 'POWERPNT', 'OUTLOOK', 'MSACCESS', 'MSPUB', 'ONENOTE', 'ONENOTEM',
    'VISIO', 'WINPROJ', 'LYNC', 'teams', 'OfficeClickToRun', 'OfficeC2RClient', 'AppVShNotify',
    'IntegratedOffice', 'officeappsrv', 'MSOSYNC', 'MSOUC', 'GROOVE', 'INFOPATH', 'OfficeSetup',
    'setup', 'OSPPSVC', 'SDXHelper', 'mscorsvw_office', 'ose', 'ose64'
)
foreach ($name in $processNames) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
        # Only touch 'setup'/'ose' when they belong to an Office folder
        if ($name -in @('setup', 'ose', 'ose64') -and $_.Path -notmatch 'Office|ClickToRun') { return }
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        Write-Log "Stopped process: $($_.ProcessName)"
    }
}

foreach ($svc in @('ClickToRunSvc', 'OfficeSvc', 'ose', 'ose64', 'OSPPSVC')) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Write-Log "Stopped service: $svc"
    }
}

# ---------------------------------------------------------------- 2. official Click-to-Run uninstall
$c2rClient = Join-Path ${env:ProgramFiles} 'Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe'
$c2rConfig = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'

if ((Test-Path $c2rClient) -and (Test-Path $c2rConfig)) {
    $cfg      = Get-ItemProperty -Path $c2rConfig -ErrorAction SilentlyContinue
    $products = @()
    if ($cfg.ProductReleaseIds) { $products = $cfg.ProductReleaseIds -split ',' | Where-Object { $_ } }
    $platform = if ($cfg.Platform) { $cfg.Platform } else { 'x64' }
    $culture  = if ($cfg.ClientCulture) { $cfg.ClientCulture } else { 'pt-br' }

    Write-Log "Click-to-Run products detected: $($products -join ', ')"

    foreach ($product in $products) {
        $args = "scenario=install scenariosub=UNINSTALL platform=$platform productstoremove=$product.16_${culture}_x-none " +
                "culture=$culture version.16=16.0 DisplayLevel=False forceappshutdown=True"
        Write-Log "Uninstalling $product via OfficeClickToRun.exe"
        $proc = Start-Process -FilePath $c2rClient -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
        Write-Log "Exit code for ${product}: $($proc.ExitCode)"
    }

    # Wait for the C2R client to finish its background work
    $deadline = (Get-Date).AddMinutes(15)
    while ((Get-Process -Name 'OfficeClickToRun', 'OfficeC2RClient' -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5
    }
}
else {
    Write-Log 'No Click-to-Run installation detected via registry/client.'
}

# ---------------------------------------------------------------- 3. MSI-based Office (2007/2010/2013/2016 MSI)
$uninstallRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)
foreach ($root in $uninstallRoots) {
    Get-ChildItem -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
        $item = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
        if (-not $item.DisplayName) { return }
        if ($item.DisplayName -notmatch '^Microsoft (Office|365 Apps)|^Office \d+') { return }
        if ($item.DisplayName -match 'Visual Studio|Update for|Security Update|Teams Machine') { return }

        if ($_.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$') {
            Write-Log "Uninstalling MSI: $($item.DisplayName)"
            $msi = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/x $($_.PSChildName) /qn /norestart REBOOT=ReallySuppress" -Wait -PassThru
            Write-Log "MSI exit code: $($msi.ExitCode)"
        }
        elseif ($item.UninstallString -match 'OfficeClickToRun') {
            Write-Log "Uninstalling via C2R string: $($item.DisplayName)"
            $c2rArgs = ($item.UninstallString -replace '^.*OfficeClickToRun\.exe"?\s*', '') + ' DisplayLevel=False forceappshutdown=True'
            Start-Process -FilePath $c2rClient -ArgumentList $c2rArgs -Wait -WindowStyle Hidden
        }
    }
}

# ---------------------------------------------------------------- 4. remove licenses (activation wizard source)
$osppPaths = @(
    "${env:ProgramFiles}\Microsoft Office\Office16\OSPP.VBS",
    "${env:ProgramFiles(x86)}\Microsoft Office\Office16\OSPP.VBS"
)
foreach ($ospp in $osppPaths) {
    if (-not (Test-Path $ospp)) { continue }
    $status = & cscript.exe //nologo $ospp /dstatus 2>$null
    $keys   = $status | Select-String 'Last 5 characters of installed product key:\s*(\w{5})' |
              ForEach-Object { $_.Matches[0].Groups[1].Value }
    foreach ($key in $keys) {
        & cscript.exe //nologo $ospp "/unpkey:$key" | Out-Null
        Write-Log "Removed product key ending in $key"
    }
}

# Licensing entries left in the Software Protection Platform for Office
Get-CimInstance -ClassName SoftwareLicensingProduct -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'Office*' -and $_.PartialProductKey } |
    ForEach-Object {
        try { $_ | Invoke-CimMethod -MethodName UninstallProductKey | Out-Null; Write-Log "Uninstalled license: $($_.Name)" }
        catch { Write-Log "Failed to remove license $($_.Name): $_" 'WARN' }
    }

# ---------------------------------------------------------------- 5. scheduled tasks
Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskPath -like '\Microsoft\Office\*' -or $_.TaskName -like 'Office*' } |
    ForEach-Object {
        Unregister-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log "Removed scheduled task: $($_.TaskPath)$($_.TaskName)"
    }

# ---------------------------------------------------------------- 6. leftover services
foreach ($svc in @('ClickToRunSvc', 'OfficeSvc')) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        sc.exe delete $svc | Out-Null
        Write-Log "Deleted service: $svc"
    }
}

# ---------------------------------------------------------------- 7. leftover files and folders
$folders = @(
    "${env:ProgramFiles}\Microsoft Office",
    "${env:ProgramFiles(x86)}\Microsoft Office",
    "${env:ProgramFiles}\Microsoft Office 15",
    "${env:ProgramFiles}\Common Files\Microsoft Shared\ClickToRun",
    "${env:ProgramFiles}\Common Files\Microsoft Shared\OFFICE16",
    "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\OFFICE16",
    "${env:ProgramData}\Microsoft\Office",
    "${env:ProgramData}\Microsoft\ClickToRun",
    "${env:ProgramData}\Microsoft\OfficeSoftwareProtectionPlatform",
    "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Microsoft Office Tools"
)
foreach ($folder in $folders) { Remove-PathSafe $folder }

# Shortcuts for Office apps in Start Menu and public desktop
$shortcutRoots = @(
    "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs",
    "${env:PUBLIC}\Desktop"
)
foreach ($root in $shortcutRoots) {
    Get-ChildItem -Path $root -Filter '*.lnk' -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -match '^(Word|Excel|PowerPoint|Outlook|Access|Publisher|OneNote|Visio|Project|Skype for Business)( \d{4})?$' } |
        ForEach-Object { Remove-PathSafe $_.FullName }
}

# Per-user data (every profile)
Get-ChildItem -Path 'C:\Users' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $profilePath = $_.FullName
    foreach ($relative in @(
        'AppData\Local\Microsoft\Office',
        'AppData\Roaming\Microsoft\Office',
        'AppData\Roaming\Microsoft\Templates',
        'AppData\Local\Microsoft\OneNote',
        'AppData\Roaming\Microsoft\Word',
        'AppData\Roaming\Microsoft\Excel',
        'AppData\Roaming\Microsoft\PowerPoint',
        'AppData\Roaming\Microsoft\Outlook',
        'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Office Tools'
    )) {
        Remove-PathSafe (Join-Path $profilePath $relative)
    }
    Get-ChildItem -Path (Join-Path $profilePath 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs') -Filter '*.lnk' -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -match '^(Word|Excel|PowerPoint|Outlook|Access|Publisher|OneNote)( \d{4})?$' } |
        ForEach-Object { Remove-PathSafe $_.FullName }
}

# ---------------------------------------------------------------- 8. leftover registry keys
$registryKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Office',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office',
    'HKLM:\SOFTWARE\Microsoft\AppVISV',
    'HKLM:\SOFTWARE\Microsoft\OfficeSoftwareProtectionPlatform',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\winword.exe',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\excel.exe',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\powerpnt.exe',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\outlook.exe',
    'HKLM:\SYSTEM\CurrentControlSet\Services\ClickToRunSvc',
    'HKLM:\SYSTEM\CurrentControlSet\Services\OfficeSvc'
)
foreach ($key in $registryKeys) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Removed registry key: $key"
    }
}

# Uninstall entries still pointing to Office
foreach ($root in $uninstallRoots) {
    Get-ChildItem -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
        $item = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
        if ($item.DisplayName -match '^Microsoft Office|^Microsoft 365 Apps|^Office \d+' -or $_.PSChildName -match 'O365|Office16|ProPlus|Standard2021|LTSC') {
            Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed uninstall entry: $($item.DisplayName)"
        }
    }
}

# Per-user registry (loaded hives + offline NTUSER.DAT)
$loadedSids = Get-ChildItem -Path 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match '^S-1-5-21-' -and $_.PSChildName -notmatch '_Classes$' }
foreach ($hive in $loadedSids) {
    foreach ($sub in @('Software\Microsoft\Office', 'Software\Microsoft\VBA', 'Software\Microsoft\Shared Tools')) {
        $path = "Registry::HKEY_USERS\$($hive.PSChildName)\$sub"
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed registry key: $path"
        }
    }
}

# ---------------------------------------------------------------- 9. finish
Write-Log '=== Office uninstall finished ==='

$stillInstalled = (Test-Path "${env:ProgramFiles}\Microsoft Office\root\Office16\WINWORD.EXE") -or
                  (Test-Path "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\WINWORD.EXE")
if ($stillInstalled) {
    Write-Log 'Office binaries still present. A reboot may be required to finish removal.' 'WARN'
    exit 3010
}
exit 0

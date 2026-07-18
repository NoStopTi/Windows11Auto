#Requires -RunAsAdministrator
param(
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ── Core: shared infrastructure ──
. "$PSScriptRoot\core\Logger.ps1"
. "$PSScriptRoot\core\ResultTracker.ps1"
. "$PSScriptRoot\core\RegistryHelper.ps1"
. "$PSScriptRoot\core\TamperProtectionCheck.ps1"
. "$PSScriptRoot\core\StateBackup.ps1"

# ── Modules: each with a single responsibility ──
. "$PSScriptRoot\modules\Disable-DefenderProtections.ps1"
. "$PSScriptRoot\modules\Disable-SmartScreen.ps1"
. "$PSScriptRoot\modules\Disable-PhishingProtection.ps1"
. "$PSScriptRoot\modules\Disable-ExploitProtection.ps1"
. "$PSScriptRoot\modules\Disable-WindowsFirewall.ps1"
. "$PSScriptRoot\modules\Disable-UAC.ps1"
. "$PSScriptRoot\modules\Disable-WindowsUpdate.ps1"
. "$PSScriptRoot\modules\Disable-DevDriveProtection.ps1"
. "$PSScriptRoot\modules\Disable-SecurityServices.ps1"

# ── Execution ──

Write-Host ""
Write-Host "============================================================" -ForegroundColor Red
Write-Host "  SECURITY ASSESSMENT - LOWEST SECURITY CONFIGURATION" -ForegroundColor Red
Write-Host "  This script DISABLES Windows security protections" -ForegroundColor Red
Write-Host "  Use highestSecurity\enable-all-security.ps1 to revert" -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Red
Write-Host ""

Write-Log "Starting security disablement..."
Write-Log "WhatIf mode: $WhatIf"

$script:SafeModeRebootPending = $false

Export-CurrentState

Disable-TamperProtection      -WhatIf:$WhatIf

if ($script:SafeModeRebootPending) {
    Show-ResultSummary

    Write-Host ""
    Write-Host "Do you want to restart now in Safe Mode? (Y/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    if ($response -match '^[Yy]') {
        Write-Log "Restarting in Safe Mode in 15 seconds..." -Level 'WARN'
        & shutdown /r /t 15 /c "Restarting in Safe Mode to disable Tamper Protection"
    }
    else {
        Write-Log "Restart postponed. Run 'shutdown /r /t 0' when ready." -Level 'WARN'
        Write-Log "Safe Mode is already configured - the next restart will be in Safe Mode." -Level 'WARN'
        Write-Log "To cancel: bcdedit /deletevalue {current} safeboot" -Level 'WARN'
    }

    Write-Host ""
    Write-Host "After the double restart (Safe Mode -> Normal), run this script again." -ForegroundColor Cyan
    Write-Host ""
    return
}

Disable-DefenderProtections   -WhatIf:$WhatIf
Disable-SmartScreen           -WhatIf:$WhatIf
Disable-PhishingProtection    -WhatIf:$WhatIf
Disable-ExploitProtection     -WhatIf:$WhatIf
Disable-WindowsFirewall       -WhatIf:$WhatIf
Disable-UAC                   -WhatIf:$WhatIf
Disable-WindowsUpdateSecurity -WhatIf:$WhatIf
Disable-DevDriveProtection    -WhatIf:$WhatIf
Disable-SecurityServices      -WhatIf:$WhatIf

Show-ResultSummary

if (-not $WhatIf) {
    Write-Host ""
    Write-Log "IMPORTANT: Some changes require a restart (UAC, services)." -Level 'WARN'
    Write-Log "Run 'shutdown /r /t 60 /c Security Test Reboot' to restart in 60 seconds." -Level 'WARN'
}

Write-Host ""
Write-Host "To REVERT all changes, run:" -ForegroundColor Green
Write-Host "  ..\highestSecurity\enable-all-security.ps1" -ForegroundColor Green
Write-Host ""

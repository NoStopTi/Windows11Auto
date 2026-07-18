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

# ── Modules: each with a single responsibility ──
. "$PSScriptRoot\modules\Enable-DefenderProtections.ps1"
. "$PSScriptRoot\modules\Enable-SmartScreen.ps1"
. "$PSScriptRoot\modules\Enable-PhishingProtection.ps1"
. "$PSScriptRoot\modules\Enable-ExploitProtection.ps1"
. "$PSScriptRoot\modules\Enable-WindowsFirewall.ps1"
. "$PSScriptRoot\modules\Enable-UAC.ps1"
. "$PSScriptRoot\modules\Enable-WindowsUpdate.ps1"
. "$PSScriptRoot\modules\Enable-DevDriveProtection.ps1"
. "$PSScriptRoot\modules\Enable-SecurityServices.ps1"
. "$PSScriptRoot\modules\Update-DefenderSignatures.ps1"

# ── Execution ──

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  SECURITY ASSESSMENT - HIGHEST SECURITY CONFIGURATION" -ForegroundColor Green
Write-Host "  This script RE-ENABLES all security protections" -ForegroundColor Green
Write-Host "  Reverts everything that lowestSecurity\disable-all-security.ps1 did" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

Write-Log "Starting security re-enablement..."
Write-Log "WhatIf mode: $WhatIf"

Enable-DefenderProtections   -WhatIf:$WhatIf
Enable-SmartScreen           -WhatIf:$WhatIf
Enable-PhishingProtection    -WhatIf:$WhatIf
Enable-ExploitProtection     -WhatIf:$WhatIf
Enable-WindowsFirewall       -WhatIf:$WhatIf
Enable-UAC                   -WhatIf:$WhatIf
Enable-WindowsUpdateSecurity -WhatIf:$WhatIf
Enable-DevDriveProtection    -WhatIf:$WhatIf
Enable-SecurityServices      -WhatIf:$WhatIf
Update-DefenderSignatures    -WhatIf:$WhatIf

Show-ResultSummary

Write-Host ""
Write-Log "IMPORTANT: Some changes require a restart (UAC, services)." -Level 'WARN'
Write-Log "Run 'shutdown /r /t 60 /c Security Restore Reboot' to restart in 60 seconds." -Level 'WARN'

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  All protections have been successfully restored!" -ForegroundColor Green
Write-Host "  Recommendation: restart the computer to ensure" -ForegroundColor Green
Write-Host "  all services and drivers are reloaded." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

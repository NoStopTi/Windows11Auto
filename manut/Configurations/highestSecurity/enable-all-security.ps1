#Requires -RunAsAdministrator
param(
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ── Core: infraestrutura compartilhada ──
. "$PSScriptRoot\core\Logger.ps1"
. "$PSScriptRoot\core\ResultTracker.ps1"
. "$PSScriptRoot\core\RegistryHelper.ps1"

# ── Modules: cada um com responsabilidade unica ──
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

# ── Execucao ──

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  SECURITY ASSESSMENT - HIGHEST SECURITY CONFIGURATION" -ForegroundColor Green
Write-Host "  Este script REATIVA todas as protecoes de seguranca" -ForegroundColor Green
Write-Host "  Reverte tudo que lowestSecurity\disable-all-security.ps1 fez" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

Write-Log "Iniciando reativacao de seguranca..."
Write-Log "Modo WhatIf: $WhatIf"

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
Write-Log "IMPORTANTE: Algumas alteracoes requerem reinicializacao (UAC, servicos)." -Level 'WARN'
Write-Log "Execute 'shutdown /r /t 60 /c Security Restore Reboot' para reiniciar em 60 segundos." -Level 'WARN'

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Todas as protecoes foram restauradas com sucesso!" -ForegroundColor Green
Write-Host "  Recomendacao: reinicie o computador para garantir" -ForegroundColor Green
Write-Host "  que todos os servicos e drivers sejam recarregados." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

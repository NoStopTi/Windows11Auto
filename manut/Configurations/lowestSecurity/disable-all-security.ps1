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
. "$PSScriptRoot\core\TamperProtectionCheck.ps1"
. "$PSScriptRoot\core\StateBackup.ps1"

# ── Modules: cada um com responsabilidade unica ──
. "$PSScriptRoot\modules\Disable-DefenderProtections.ps1"
. "$PSScriptRoot\modules\Disable-SmartScreen.ps1"
. "$PSScriptRoot\modules\Disable-PhishingProtection.ps1"
. "$PSScriptRoot\modules\Disable-ExploitProtection.ps1"
. "$PSScriptRoot\modules\Disable-WindowsFirewall.ps1"
. "$PSScriptRoot\modules\Disable-UAC.ps1"
. "$PSScriptRoot\modules\Disable-WindowsUpdate.ps1"
. "$PSScriptRoot\modules\Disable-DevDriveProtection.ps1"
. "$PSScriptRoot\modules\Disable-SecurityServices.ps1"

# ── Execucao ──

Write-Host ""
Write-Host "============================================================" -ForegroundColor Red
Write-Host "  SECURITY ASSESSMENT - LOWEST SECURITY CONFIGURATION" -ForegroundColor Red
Write-Host "  Este script DESATIVA as protecoes de seguranca do Windows" -ForegroundColor Red
Write-Host "  Use highestSecurity\enable-all-security.ps1 para reverter" -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Red
Write-Host ""

Write-Log "Iniciando desativacao de seguranca..."
Write-Log "Modo WhatIf: $WhatIf"

$script:SafeModeRebootPending = $false

Export-CurrentState

Disable-TamperProtection      -WhatIf:$WhatIf

if ($script:SafeModeRebootPending) {
    Show-ResultSummary

    Write-Host ""
    Write-Host "Deseja reiniciar agora em Safe Mode? (S/N): " -ForegroundColor Yellow -NoNewline
    $resposta = Read-Host
    if ($resposta -match '^[Ss]') {
        Write-Log "Reiniciando em Safe Mode em 15 segundos..." -Level 'WARN'
        & shutdown /r /t 15 /c "Reiniciando em Safe Mode para desativar Tamper Protection"
    }
    else {
        Write-Log "Reinicio adiado. Execute 'shutdown /r /t 0' quando estiver pronto." -Level 'WARN'
        Write-Log "O Safe Mode ja esta configurado - o proximo reinicio sera em Safe Mode." -Level 'WARN'
        Write-Log "Para cancelar: bcdedit /deletevalue {current} safeboot" -Level 'WARN'
    }

    Write-Host ""
    Write-Host "Apos o duplo reinicio (Safe Mode -> Normal), execute este script novamente." -ForegroundColor Cyan
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
    Write-Log "IMPORTANTE: Algumas alteracoes requerem reinicializacao (UAC, servicos)." -Level 'WARN'
    Write-Log "Execute 'shutdown /r /t 60 /c Security Test Reboot' para reiniciar em 60 segundos." -Level 'WARN'
}

Write-Host ""
Write-Host "Para REVERTER todas as alteracoes, execute:" -ForegroundColor Green
Write-Host "  ..\highestSecurity\enable-all-security.ps1" -ForegroundColor Green
Write-Host ""

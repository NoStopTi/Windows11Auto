function Test-TamperProtection {
    try {
        $tp = (Get-MpComputerStatus).IsTamperProtected
        if ($tp) {
            Write-Log "Tamper Protection esta ATIVADA." -Level 'WARN'
            return $true
        }
        return $false
    }
    catch {
        Write-Log "Nao foi possivel verificar Tamper Protection: $_" -Level 'WARN'
        return $false
    }
}

function Disable-TamperProtection {
    param([switch]$WhatIf)

    Write-Log "=== Tamper Protection (Protecao contra Violacoes) ==="

    if ($WhatIf) {
        Write-Log "[WHATIF] Desativaria Tamper Protection via Safe Mode reboot"
        Add-Result 'Defender' 'Tamper Protection' 'WHATIF'
        return
    }

    $initialState = Test-TamperProtection
    if (-not $initialState) {
        Write-Log "Tamper Protection ja esta desativada" -Level 'OK'
        Add-Result 'Defender' 'Tamper Protection' 'DISABLED'
        return
    }

    Write-Log "Tamper Protection ativa - protecao a nivel de kernel impede desativacao em modo normal." -Level 'WARN'
    Write-Log "Preparando reinicio automatico em Safe Mode para desativar..." -Level 'INFO'

    $scriptDir = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { $PWD.Path }
    $batchPath = Join-Path $env:TEMP 'disable-tamper-safemode.cmd'

    $batchContent = @"
@echo off
echo ============================================================
echo   Desativando Tamper Protection em Safe Mode...
echo ============================================================

reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\Features" /v TamperProtection /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\Features" /v TamperProtectionSource /t REG_DWORD /d 0 /f

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableBehaviorMonitoring /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableOnAccessProtection /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableScanOnRealtimeEnable /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v DisableIOAVProtection /t REG_DWORD /d 1 /f

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v DisableAntiVirus /t REG_DWORD /d 1 /f

reg add "HKLM\SYSTEM\CurrentControlSet\Services\WinDefend" /v Start /t REG_DWORD /d 4 /f

bcdedit /deletevalue {current} safeboot

echo ============================================================
echo   Tamper Protection desativada. Reiniciando em modo normal...
echo ============================================================

shutdown /r /t 10 /c "Retornando ao modo normal - Tamper Protection desativada"
"@

    try {
        Set-Content -Path $batchPath -Value $batchContent -Encoding ASCII -Force -ErrorAction Stop
        Write-Log "Script Safe Mode criado: $batchPath" -Level 'OK'
    }
    catch {
        Write-Log "Falha ao criar script Safe Mode: $_" -Level 'ERROR'
        Add-Result 'Defender' 'Tamper Protection' 'FAILED' 'Nao foi possivel criar script de Safe Mode'
        return
    }

    try {
        & reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v DisableTamperProtection /t REG_SZ /d "`"$batchPath`"" /f 2>&1 | Out-Null
        Write-Log "RunOnce registrado para executar em Safe Mode" -Level 'OK'
    }
    catch {
        Write-Log "Falha ao registrar RunOnce: $_" -Level 'ERROR'
        Add-Result 'Defender' 'Tamper Protection' 'FAILED' 'Nao foi possivel registrar RunOnce'
        return
    }

    try {
        & bcdedit /set "{current}" safeboot minimal 2>&1 | Out-Null
        Write-Log "Safe Mode configurado para proximo boot" -Level 'OK'
    }
    catch {
        Write-Log "Falha ao configurar Safe Mode: $_" -Level 'ERROR'
        & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v DisableTamperProtection /f 2>&1 | Out-Null
        Add-Result 'Defender' 'Tamper Protection' 'FAILED' 'Nao foi possivel configurar Safe Mode boot'
        return
    }

    Add-Result 'Defender' 'Tamper Protection' 'REBOOT_REQUIRED' 'Safe Mode reboot automatico configurado'

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "  REINICIO EM SAFE MODE NECESSARIO" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  O computador ira:" -ForegroundColor Cyan
    Write-Host "    1. Reiniciar em Safe Mode" -ForegroundColor Cyan
    Write-Host "    2. Faca login com sua conta normalmente" -ForegroundColor Cyan
    Write-Host "    3. O script automatico desativa Tamper Protection" -ForegroundColor Cyan
    Write-Host "    4. Reinicia em modo normal automaticamente" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Apos o duplo reinicio, execute este script novamente" -ForegroundColor Cyan
    Write-Host "  para confirmar que tudo esta desativado." -ForegroundColor Cyan
    Write-Host ""

    $script:SafeModeRebootPending = $true
}

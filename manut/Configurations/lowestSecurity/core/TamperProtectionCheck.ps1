function Test-TamperProtection {
    try {
        $tp = (Get-MpComputerStatus).IsTamperProtected
        if ($tp) {
            Write-Log "Tamper Protection is ENABLED." -Level 'WARN'
            return $true
        }
        return $false
    }
    catch {
        Write-Log "Could not check Tamper Protection: $_" -Level 'WARN'
        return $false
    }
}

function Disable-TamperProtection {
    param([switch]$WhatIf)

    Write-Log "=== Tamper Protection ==="

    if ($WhatIf) {
        Write-Log "[WHATIF] Would disable Tamper Protection via Safe Mode reboot"
        Add-Result 'Defender' 'Tamper Protection' 'WHATIF'
        return
    }

    $initialState = Test-TamperProtection
    if (-not $initialState) {
        Write-Log "Tamper Protection is already disabled" -Level 'OK'
        Add-Result 'Defender' 'Tamper Protection' 'DISABLED'
        return
    }

    Write-Log "Tamper Protection active - kernel-level protection prevents disabling in normal mode." -Level 'WARN'
    Write-Log "Preparing automatic reboot into Safe Mode to disable it..." -Level 'INFO'

    $scriptDir = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { $PWD.Path }
    $batchPath = Join-Path $env:TEMP 'disable-tamper-safemode.cmd'

    $batchContent = @"
@echo off
echo ============================================================
echo   Disabling Tamper Protection in Safe Mode...
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
echo   Tamper Protection disabled. Restarting in normal mode...
echo ============================================================

shutdown /r /t 10 /c "Returning to normal mode - Tamper Protection disabled"
"@

    try {
        Set-Content -Path $batchPath -Value $batchContent -Encoding ASCII -Force -ErrorAction Stop
        Write-Log "Safe Mode script created: $batchPath" -Level 'OK'
    }
    catch {
        Write-Log "Failed to create Safe Mode script: $_" -Level 'ERROR'
        Add-Result 'Defender' 'Tamper Protection' 'FAILED' 'Could not create Safe Mode script'
        return
    }

    try {
        & reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v DisableTamperProtection /t REG_SZ /d "`"$batchPath`"" /f 2>&1 | Out-Null
        Write-Log "RunOnce registered to run in Safe Mode" -Level 'OK'
    }
    catch {
        Write-Log "Failed to register RunOnce: $_" -Level 'ERROR'
        Add-Result 'Defender' 'Tamper Protection' 'FAILED' 'Could not register RunOnce'
        return
    }

    try {
        & bcdedit /set "{current}" safeboot minimal 2>&1 | Out-Null
        Write-Log "Safe Mode configured for next boot" -Level 'OK'
    }
    catch {
        Write-Log "Failed to configure Safe Mode: $_" -Level 'ERROR'
        & reg.exe delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v DisableTamperProtection /f 2>&1 | Out-Null
        Add-Result 'Defender' 'Tamper Protection' 'FAILED' 'Could not configure Safe Mode boot'
        return
    }

    Add-Result 'Defender' 'Tamper Protection' 'REBOOT_REQUIRED' 'Automatic Safe Mode reboot configured'

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "  SAFE MODE RESTART REQUIRED" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  The computer will:" -ForegroundColor Cyan
    Write-Host "    1. Restart in Safe Mode" -ForegroundColor Cyan
    Write-Host "    2. Log in with your account normally" -ForegroundColor Cyan
    Write-Host "    3. The automatic script disables Tamper Protection" -ForegroundColor Cyan
    Write-Host "    4. Restarts in normal mode automatically" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  After the double restart, run this script again" -ForegroundColor Cyan
    Write-Host "  to confirm everything is disabled." -ForegroundColor Cyan
    Write-Host ""

    $script:SafeModeRebootPending = $true
}

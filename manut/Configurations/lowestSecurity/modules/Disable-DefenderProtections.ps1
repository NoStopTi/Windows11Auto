function Disable-DefenderProtections {
    param([switch]$WhatIf)

    Write-Log "=== Microsoft Defender Antivirus ==="

    $settings = @(
        @{ Param = 'DisableRealtimeMonitoring';  Value = $true; Label = 'Protecao em tempo real' }
        @{ Param = 'DisableBehaviorMonitoring';   Value = $true; Label = 'Monitoramento de comportamento' }
        @{ Param = 'DisableBlockAtFirstSeen';     Value = $true; Label = 'Block at First Seen' }
        @{ Param = 'DisableIOAVProtection';       Value = $true; Label = 'Verificacao de downloads (IOAV)' }
        @{ Param = 'DisableScriptScanning';       Value = $true; Label = 'Script Scanning' }
        @{ Param = 'MAPSReporting';               Value = 0;     Label = 'Protecao fornecida na nuvem (MAPS)' }
        @{ Param = 'SubmitSamplesConsent';         Value = 2;     Label = 'Envio automatico de amostra' }
        @{ Param = 'PUAProtection';               Value = 0;     Label = 'Bloqueio de app potencialmente indesejado (PUA)' }
        @{ Param = 'EnableControlledFolderAccess'; Value = 0;     Label = 'Acesso a pastas controladas (Ransomware)' }
    )

    foreach ($s in $settings) {
        try {
            if ($WhatIf) {
                Write-Log "[WHATIF] Desativaria: $($s.Label) ($($s.Param) = $($s.Value))"
                Add-Result 'Defender' $s.Label 'WHATIF'
                continue
            }
            $params = @{ $s.Param = $s.Value }
            Set-MpPreference @params -ErrorAction Stop
            Write-Log "Desativado: $($s.Label)" -Level 'OK'
            Add-Result 'Defender' $s.Label 'DISABLED'
        }
        catch {
            Write-Log "Falha ao desativar $($s.Label): $_" -Level 'ERROR'
            Add-Result 'Defender' $s.Label 'FAILED' $_.Exception.Message
        }
    }

    if (-not $WhatIf) {
        try {
            $status = Get-MpPreference -ErrorAction Stop
            if ($status.DisableRealtimeMonitoring -ne $true) {
                Write-Log "Protecao em tempo real nao desativou via Set-MpPreference. Tentando via SYSTEM..." -Level 'WARN'
                $systemCmd = "Set-MpPreference -DisableRealtimeMonitoring `$true -DisableBehaviorMonitoring `$true -DisableBlockAtFirstSeen `$true -DisableIOAVProtection `$true -DisableScriptScanning `$true -Force -ErrorAction SilentlyContinue"
                Invoke-AsSystem $systemCmd | Out-Null
                Start-Sleep -Seconds 2
                $recheck = Get-MpPreference -ErrorAction SilentlyContinue
                if ($recheck.DisableRealtimeMonitoring -eq $true) {
                    Write-Log "Protecao em tempo real desativada via SYSTEM" -Level 'OK'
                }
                else {
                    Write-Log "Protecao em tempo real resistiu. Aplicando via registro protegido..." -Level 'WARN'
                    Set-ProtectedRegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection' 'DisableRealtimeMonitoring' 1 | Out-Null
                }
            }
        }
        catch {
            Write-Log "Falha na verificacao pos-aplicacao: $_" -Level 'WARN'
        }
    }

    if (-not $WhatIf) {
        try {
            Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' 'DisableAntiSpyware' 1 | Out-Null
            Write-Log "Desativado: Defender AntiSpyware via GPO" -Level 'OK'
            Add-Result 'Defender' 'AntiSpyware (GPO)' 'DISABLED'
        }
        catch {
            Write-Log "Falha AntiSpyware GPO: $_" -Level 'ERROR'
            Add-Result 'Defender' 'AntiSpyware (GPO)' 'FAILED' $_.Exception.Message
        }

        Write-Log "Aplicando fallbacks via GPO (registro) para protecao em tempo real..."

        $gpoRtpPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
        $gpoRtpKeys = @(
            @{ Name = 'DisableRealtimeMonitoring';   Value = 1; Label = 'Protecao em tempo real (GPO)' }
            @{ Name = 'DisableBehaviorMonitoring';    Value = 1; Label = 'Monitoramento de comportamento (GPO)' }
            @{ Name = 'DisableOnAccessProtection';    Value = 1; Label = 'Protecao de acesso (GPO)' }
            @{ Name = 'DisableScanOnRealtimeEnable';  Value = 1; Label = 'Scan em tempo real (GPO)' }
            @{ Name = 'DisableIOAVProtection';        Value = 1; Label = 'Verificacao IOAV (GPO)' }
        )

        foreach ($key in $gpoRtpKeys) {
            try {
                Set-RegistryValue $gpoRtpPath $key.Name $key.Value | Out-Null
                Write-Log "Desativado: $($key.Label)" -Level 'OK'
                Add-Result 'Defender' $key.Label 'DISABLED'
            }
            catch {
                Write-Log "Falha $($key.Label): $_" -Level 'ERROR'
                Add-Result 'Defender' $key.Label 'FAILED' $_.Exception.Message
            }
        }

        $gpoSpynetPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'
        try {
            Set-RegistryValue $gpoSpynetPath 'SpynetReporting' 0 | Out-Null
            Set-RegistryValue $gpoSpynetPath 'SubmitSamplesConsent' 2 | Out-Null
            Write-Log "Desativado: Cloud Protection e envio de amostras (GPO)" -Level 'OK'
            Add-Result 'Defender' 'Cloud/Samples (GPO)' 'DISABLED'
        }
        catch {
            Write-Log "Falha Cloud/Samples GPO: $_" -Level 'ERROR'
            Add-Result 'Defender' 'Cloud/Samples (GPO)' 'FAILED' $_.Exception.Message
        }

        try {
            Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' 'DisableAntiVirus' 1 | Out-Null
            Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' 'DisableRoutinelyTakingAction' 1 | Out-Null
            Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' 'ServiceKeepAlive' 0 | Out-Null
            Write-Log "Desativado: Defender AntiVirus/Actions/KeepAlive (GPO)" -Level 'OK'
            Add-Result 'Defender' 'AntiVirus/Actions (GPO)' 'DISABLED'
        }
        catch {
            Write-Log "Falha AntiVirus/Actions GPO: $_" -Level 'ERROR'
            Add-Result 'Defender' 'AntiVirus/Actions (GPO)' 'FAILED' $_.Exception.Message
        }

        try {
            $winDefendPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend'
            $wdOk = Set-ProtectedRegistryValue $winDefendPath 'Start' 4
            if ($wdOk) {
                Write-Log "Desativado: Servico WinDefend (startup disabled)" -Level 'OK'
                Add-Result 'Defender' 'WinDefend Service (Registry)' 'DISABLED'
            }
            else {
                Write-Log "Tentando WinDefend via SYSTEM..." -Level 'WARN'
                $sysOk = Invoke-AsSystem "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend' -Name 'Start' -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue"
                if ($sysOk) {
                    Write-Log "Desativado: Servico WinDefend via SYSTEM" -Level 'OK'
                    Add-Result 'Defender' 'WinDefend Service (Registry)' 'DISABLED'
                }
                else {
                    Write-Log "Falha WinDefend service registry (todas tentativas)" -Level 'ERROR'
                    Add-Result 'Defender' 'WinDefend Service (Registry)' 'FAILED' 'Acesso negado mesmo como SYSTEM'
                }
            }
        }
        catch {
            Write-Log "Falha WinDefend service registry: $_" -Level 'ERROR'
            Add-Result 'Defender' 'WinDefend Service (Registry)' 'FAILED' $_.Exception.Message
        }
    }
}

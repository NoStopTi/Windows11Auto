function Enable-DefenderProtections {
    param([switch]$WhatIf)

    Write-Log "=== Microsoft Defender Antivirus ==="

    $settings = @(
        @{ Param = 'DisableRealtimeMonitoring';  Value = $false; Label = 'Protecao em tempo real' }
        @{ Param = 'DisableBehaviorMonitoring';   Value = $false; Label = 'Monitoramento de comportamento' }
        @{ Param = 'DisableBlockAtFirstSeen';     Value = $false; Label = 'Block at First Seen' }
        @{ Param = 'DisableIOAVProtection';       Value = $false; Label = 'Verificacao de downloads (IOAV)' }
        @{ Param = 'DisableScriptScanning';       Value = $false; Label = 'Script Scanning' }
        @{ Param = 'MAPSReporting';               Value = 2;      Label = 'Protecao fornecida na nuvem (MAPS Advanced)' }
        @{ Param = 'SubmitSamplesConsent';         Value = 1;      Label = 'Envio automatico de amostra (Safe Samples)' }
        @{ Param = 'PUAProtection';               Value = 1;      Label = 'Bloqueio de app potencialmente indesejado (PUA)' }
        @{ Param = 'EnableControlledFolderAccess'; Value = 1;      Label = 'Acesso a pastas controladas (Ransomware)' }
    )

    foreach ($s in $settings) {
        try {
            if ($WhatIf) {
                Write-Log "[WHATIF] Ativaria: $($s.Label) ($($s.Param) = $($s.Value))"
                Add-Result 'Defender' $s.Label 'WHATIF'
                continue
            }
            $params = @{ $s.Param = $s.Value }
            Set-MpPreference @params
            Write-Log "Ativado: $($s.Label)" -Level 'OK'
            Add-Result 'Defender' $s.Label 'ENABLED'
        }
        catch {
            Write-Log "Falha ao ativar $($s.Label): $_" -Level 'ERROR'
            Add-Result 'Defender' $s.Label 'FAILED' $_.Exception.Message
        }
    }

    if (-not $WhatIf) {
        try {
            Remove-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' 'DisableAntiSpyware' | Out-Null
            Write-Log "Removido: Defender AntiSpyware GPO override (restaura padrao)" -Level 'OK'
            Add-Result 'Defender' 'AntiSpyware (GPO)' 'ENABLED'
        }
        catch {
            Write-Log "Falha AntiSpyware GPO: $_" -Level 'ERROR'
            Add-Result 'Defender' 'AntiSpyware (GPO)' 'FAILED' $_.Exception.Message
        }
    }
}

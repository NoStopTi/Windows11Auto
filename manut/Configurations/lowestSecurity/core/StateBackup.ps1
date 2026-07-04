function Export-CurrentState {
    $stateFile = Join-Path $PSScriptRoot "..\security-state-backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    Write-Log "Exportando estado atual das configuracoes para: $stateFile"
    try {
        $mpPref   = Get-MpPreference
        $mpStatus = Get-MpComputerStatus
        $fwProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled

        $state = @{
            Timestamp                    = (Get-Date).ToString('o')
            DisableRealtimeMonitoring    = $mpPref.DisableRealtimeMonitoring
            MAPSReporting                = $mpPref.MAPSReporting
            SubmitSamplesConsent         = $mpPref.SubmitSamplesConsent
            PUAProtection                = $mpPref.PUAProtection
            EnableControlledFolderAccess = $mpPref.EnableControlledFolderAccess
            DisableIOAVProtection        = $mpPref.DisableIOAVProtection
            DisableBehaviorMonitoring    = $mpPref.DisableBehaviorMonitoring
            DisableBlockAtFirstSeen      = $mpPref.DisableBlockAtFirstSeen
            DisableScriptScanning        = $mpPref.DisableScriptScanning
            IsTamperProtected            = $mpStatus.IsTamperProtected
            FirewallProfiles             = $fwProfiles
        }

        $state | ConvertTo-Json -Depth 5 | Set-Content -Path $stateFile -Encoding UTF8
        Write-Log "Backup do estado salvo com sucesso" -Level 'OK'
    }
    catch {
        Write-Log "Falha ao exportar estado: $_" -Level 'ERROR'
    }
}

function Export-CurrentState {
    $stateFile = Join-Path $PSScriptRoot "..\security-state-backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    Write-Log "Exporting current settings state to: $stateFile"
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
        Write-Log "State backup saved successfully" -Level 'OK'
    }
    catch {
        Write-Log "Failed to export state: $_" -Level 'ERROR'
    }
}

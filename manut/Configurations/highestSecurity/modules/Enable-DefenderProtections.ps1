function Enable-DefenderProtections {
    param([switch]$WhatIf)

    Write-Log "=== Microsoft Defender Antivirus ==="

    $settings = @(
        @{ Param = 'DisableRealtimeMonitoring';  Value = $false; Label = 'Real-time protection' }
        @{ Param = 'DisableBehaviorMonitoring';   Value = $false; Label = 'Behavior monitoring' }
        @{ Param = 'DisableBlockAtFirstSeen';     Value = $false; Label = 'Block at First Seen' }
        @{ Param = 'DisableIOAVProtection';       Value = $false; Label = 'Download scanning (IOAV)' }
        @{ Param = 'DisableScriptScanning';       Value = $false; Label = 'Script Scanning' }
        @{ Param = 'MAPSReporting';               Value = 2;      Label = 'Cloud-delivered protection (MAPS Advanced)' }
        @{ Param = 'SubmitSamplesConsent';         Value = 1;      Label = 'Automatic sample submission (Safe Samples)' }
        @{ Param = 'PUAProtection';               Value = 1;      Label = 'Potentially unwanted app (PUA) blocking' }
        @{ Param = 'EnableControlledFolderAccess'; Value = 1;      Label = 'Controlled folder access (Ransomware)' }
    )

    foreach ($s in $settings) {
        try {
            if ($WhatIf) {
                Write-Log "[WHATIF] Would enable: $($s.Label) ($($s.Param) = $($s.Value))"
                Add-Result 'Defender' $s.Label 'WHATIF'
                continue
            }
            $params = @{ $s.Param = $s.Value }
            Set-MpPreference @params
            Write-Log "Enabled: $($s.Label)" -Level 'OK'
            Add-Result 'Defender' $s.Label 'ENABLED'
        }
        catch {
            Write-Log "Failed to enable $($s.Label): $_" -Level 'ERROR'
            Add-Result 'Defender' $s.Label 'FAILED' $_.Exception.Message
        }
    }

    if (-not $WhatIf) {
        try {
            Remove-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' 'DisableAntiSpyware' | Out-Null
            Write-Log "Removed: Defender AntiSpyware GPO override (restores default)" -Level 'OK'
            Add-Result 'Defender' 'AntiSpyware (GPO)' 'ENABLED'
        }
        catch {
            Write-Log "AntiSpyware GPO failure: $_" -Level 'ERROR'
            Add-Result 'Defender' 'AntiSpyware (GPO)' 'FAILED' $_.Exception.Message
        }
    }
}

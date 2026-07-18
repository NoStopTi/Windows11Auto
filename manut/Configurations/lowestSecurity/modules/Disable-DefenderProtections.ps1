function Disable-DefenderProtections {
    param([switch]$WhatIf)

    Write-Log "=== Microsoft Defender Antivirus ==="

    $settings = @(
        @{ Param = 'DisableRealtimeMonitoring';  Value = $true; Label = 'Real-time protection' }
        @{ Param = 'DisableBehaviorMonitoring';   Value = $true; Label = 'Behavior monitoring' }
        @{ Param = 'DisableBlockAtFirstSeen';     Value = $true; Label = 'Block at First Seen' }
        @{ Param = 'DisableIOAVProtection';       Value = $true; Label = 'Download scanning (IOAV)' }
        @{ Param = 'DisableScriptScanning';       Value = $true; Label = 'Script Scanning' }
        @{ Param = 'MAPSReporting';               Value = 0;     Label = 'Cloud-delivered protection (MAPS)' }
        @{ Param = 'SubmitSamplesConsent';         Value = 2;     Label = 'Automatic sample submission' }
        @{ Param = 'PUAProtection';               Value = 0;     Label = 'Potentially unwanted app (PUA) blocking' }
        @{ Param = 'EnableControlledFolderAccess'; Value = 0;     Label = 'Controlled folder access (Ransomware)' }
    )

    foreach ($s in $settings) {
        try {
            if ($WhatIf) {
                Write-Log "[WHATIF] Would disable: $($s.Label) ($($s.Param) = $($s.Value))"
                Add-Result 'Defender' $s.Label 'WHATIF'
                continue
            }
            $params = @{ $s.Param = $s.Value }
            Set-MpPreference @params -ErrorAction Stop
            Write-Log "Disabled: $($s.Label)" -Level 'OK'
            Add-Result 'Defender' $s.Label 'DISABLED'
        }
        catch {
            Write-Log "Failed to disable $($s.Label): $_" -Level 'ERROR'
            Add-Result 'Defender' $s.Label 'FAILED' $_.Exception.Message
        }
    }

    if (-not $WhatIf) {
        try {
            $status = Get-MpPreference -ErrorAction Stop
            if ($status.DisableRealtimeMonitoring -ne $true) {
                Write-Log "Real-time protection did not disable via Set-MpPreference. Trying via SYSTEM..." -Level 'WARN'
                $systemCmd = "Set-MpPreference -DisableRealtimeMonitoring `$true -DisableBehaviorMonitoring `$true -DisableBlockAtFirstSeen `$true -DisableIOAVProtection `$true -DisableScriptScanning `$true -Force -ErrorAction SilentlyContinue"
                Invoke-AsSystem $systemCmd | Out-Null
                Start-Sleep -Seconds 2
                $recheck = Get-MpPreference -ErrorAction SilentlyContinue
                if ($recheck.DisableRealtimeMonitoring -eq $true) {
                    Write-Log "Real-time protection disabled via SYSTEM" -Level 'OK'
                }
                else {
                    Write-Log "Real-time protection resisted. Applying via protected registry..." -Level 'WARN'
                    Set-ProtectedRegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection' 'DisableRealtimeMonitoring' 1 | Out-Null
                }
            }
        }
        catch {
            Write-Log "Post-apply verification failed: $_" -Level 'WARN'
        }
    }

    if (-not $WhatIf) {
        try {
            Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' 'DisableAntiSpyware' 1 | Out-Null
            Write-Log "Disabled: Defender AntiSpyware via GPO" -Level 'OK'
            Add-Result 'Defender' 'AntiSpyware (GPO)' 'DISABLED'
        }
        catch {
            Write-Log "AntiSpyware GPO failure: $_" -Level 'ERROR'
            Add-Result 'Defender' 'AntiSpyware (GPO)' 'FAILED' $_.Exception.Message
        }

        Write-Log "Applying GPO (registry) fallbacks for real-time protection..."

        $gpoRtpPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
        $gpoRtpKeys = @(
            @{ Name = 'DisableRealtimeMonitoring';   Value = 1; Label = 'Real-time protection (GPO)' }
            @{ Name = 'DisableBehaviorMonitoring';    Value = 1; Label = 'Behavior monitoring (GPO)' }
            @{ Name = 'DisableOnAccessProtection';    Value = 1; Label = 'On-access protection (GPO)' }
            @{ Name = 'DisableScanOnRealtimeEnable';  Value = 1; Label = 'Real-time scan (GPO)' }
            @{ Name = 'DisableIOAVProtection';        Value = 1; Label = 'IOAV scanning (GPO)' }
        )

        foreach ($key in $gpoRtpKeys) {
            try {
                Set-RegistryValue $gpoRtpPath $key.Name $key.Value | Out-Null
                Write-Log "Disabled: $($key.Label)" -Level 'OK'
                Add-Result 'Defender' $key.Label 'DISABLED'
            }
            catch {
                Write-Log "Failed $($key.Label): $_" -Level 'ERROR'
                Add-Result 'Defender' $key.Label 'FAILED' $_.Exception.Message
            }
        }

        $gpoSpynetPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'
        try {
            Set-RegistryValue $gpoSpynetPath 'SpynetReporting' 0 | Out-Null
            Set-RegistryValue $gpoSpynetPath 'SubmitSamplesConsent' 2 | Out-Null
            Write-Log "Disabled: Cloud Protection and sample submission (GPO)" -Level 'OK'
            Add-Result 'Defender' 'Cloud/Samples (GPO)' 'DISABLED'
        }
        catch {
            Write-Log "Cloud/Samples GPO failure: $_" -Level 'ERROR'
            Add-Result 'Defender' 'Cloud/Samples (GPO)' 'FAILED' $_.Exception.Message
        }

        try {
            Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' 'DisableAntiVirus' 1 | Out-Null
            Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' 'DisableRoutinelyTakingAction' 1 | Out-Null
            Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' 'ServiceKeepAlive' 0 | Out-Null
            Write-Log "Disabled: Defender AntiVirus/Actions/KeepAlive (GPO)" -Level 'OK'
            Add-Result 'Defender' 'AntiVirus/Actions (GPO)' 'DISABLED'
        }
        catch {
            Write-Log "AntiVirus/Actions GPO failure: $_" -Level 'ERROR'
            Add-Result 'Defender' 'AntiVirus/Actions (GPO)' 'FAILED' $_.Exception.Message
        }

        try {
            $winDefendPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend'
            $wdOk = Set-ProtectedRegistryValue $winDefendPath 'Start' 4
            if ($wdOk) {
                Write-Log "Disabled: WinDefend service (startup disabled)" -Level 'OK'
                Add-Result 'Defender' 'WinDefend Service (Registry)' 'DISABLED'
            }
            else {
                Write-Log "Trying WinDefend via SYSTEM..." -Level 'WARN'
                $sysOk = Invoke-AsSystem "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend' -Name 'Start' -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue"
                if ($sysOk) {
                    Write-Log "Disabled: WinDefend service via SYSTEM" -Level 'OK'
                    Add-Result 'Defender' 'WinDefend Service (Registry)' 'DISABLED'
                }
                else {
                    Write-Log "WinDefend service registry failed (all attempts)" -Level 'ERROR'
                    Add-Result 'Defender' 'WinDefend Service (Registry)' 'FAILED' 'Access denied even as SYSTEM'
                }
            }
        }
        catch {
            Write-Log "WinDefend service registry failed: $_" -Level 'ERROR'
            Add-Result 'Defender' 'WinDefend Service (Registry)' 'FAILED' $_.Exception.Message
        }
    }
}

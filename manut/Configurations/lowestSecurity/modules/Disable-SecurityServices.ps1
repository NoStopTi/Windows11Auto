function Disable-SecurityServices {
    param([switch]$WhatIf)

    Write-Log "=== Security Services ==="

    $services = @(
        @{ Name = 'WdNisSvc';             Label = 'Windows Defender Network Inspection Service' }
        @{ Name = 'SecurityHealthService'; Label = 'Windows Security Health Service' }
        @{ Name = 'wscsvc';               Label = 'Security Center Service' }
        @{ Name = 'WdFilter';             Label = 'Windows Defender Mini-Filter Driver' }
    )

    foreach ($svc in $services) {
        try {
            if ($WhatIf) {
                Write-Log "[WHATIF] Would disable service: $($svc.Label)"
                Add-Result 'Services' $svc.Label 'WHATIF'
                continue
            }
            $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if ($s) {
                try { Stop-Service -Name $svc.Name -Force -ErrorAction Stop } catch {}
                try { Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction Stop } catch {}
                Write-Log "Disabled: $($svc.Label)" -Level 'OK'
                Add-Result 'Services' $svc.Label 'DISABLED'
            }
            else {
                Write-Log "Service not found: $($svc.Name)" -Level 'WARN'
                Add-Result 'Services' $svc.Label 'NOT_FOUND'
            }
        }
        catch {
            Write-Log "Failed to disable service $($svc.Name): $_" -Level 'ERROR'
            Add-Result 'Services' $svc.Label 'FAILED' $_.Exception.Message
        }
    }
}

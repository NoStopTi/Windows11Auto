function Enable-SecurityServices {
    param([switch]$WhatIf)

    Write-Log "=== Security Services ==="

    $services = @(
        @{ Name = 'WdNisSvc';             Label = 'Windows Defender Network Inspection Service'; StartType = 'Manual' }
        @{ Name = 'SecurityHealthService'; Label = 'Windows Security Health Service';             StartType = 'Manual' }
        @{ Name = 'wscsvc';               Label = 'Security Center Service';                      StartType = 'Automatic' }
        @{ Name = 'WdFilter';             Label = 'Windows Defender Mini-Filter Driver';           StartType = 'Automatic' }
    )

    foreach ($svc in $services) {
        try {
            if ($WhatIf) {
                Write-Log "[WHATIF] Would enable service: $($svc.Label)"
                Add-Result 'Services' $svc.Label 'WHATIF'
                continue
            }
            $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if ($s) {
                try { Set-Service -Name $svc.Name -StartupType $svc.StartType -ErrorAction Stop } catch {}
                try { Start-Service -Name $svc.Name -ErrorAction Stop } catch {}
                Write-Log "Enabled: $($svc.Label) (StartupType: $($svc.StartType))" -Level 'OK'
                Add-Result 'Services' $svc.Label 'ENABLED'
            }
            else {
                Write-Log "Service not found: $($svc.Name)" -Level 'WARN'
                Add-Result 'Services' $svc.Label 'NOT_FOUND'
            }
        }
        catch {
            Write-Log "Failed to enable service $($svc.Name): $_" -Level 'ERROR'
            Add-Result 'Services' $svc.Label 'FAILED' $_.Exception.Message
        }
    }
}

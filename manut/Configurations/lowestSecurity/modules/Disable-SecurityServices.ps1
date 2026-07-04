function Disable-SecurityServices {
    param([switch]$WhatIf)

    Write-Log "=== Servicos de seguranca ==="

    $services = @(
        @{ Name = 'WdNisSvc';             Label = 'Windows Defender Network Inspection Service' }
        @{ Name = 'SecurityHealthService'; Label = 'Windows Security Health Service' }
        @{ Name = 'wscsvc';               Label = 'Security Center Service' }
        @{ Name = 'WdFilter';             Label = 'Windows Defender Mini-Filter Driver' }
    )

    foreach ($svc in $services) {
        try {
            if ($WhatIf) {
                Write-Log "[WHATIF] Desativaria servico: $($svc.Label)"
                Add-Result 'Servicos' $svc.Label 'WHATIF'
                continue
            }
            $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if ($s) {
                try { Stop-Service -Name $svc.Name -Force -ErrorAction Stop } catch {}
                try { Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction Stop } catch {}
                Write-Log "Desativado: $($svc.Label)" -Level 'OK'
                Add-Result 'Servicos' $svc.Label 'DISABLED'
            }
            else {
                Write-Log "Servico nao encontrado: $($svc.Name)" -Level 'WARN'
                Add-Result 'Servicos' $svc.Label 'NOT_FOUND'
            }
        }
        catch {
            Write-Log "Falha ao desativar servico $($svc.Name): $_" -Level 'ERROR'
            Add-Result 'Servicos' $svc.Label 'FAILED' $_.Exception.Message
        }
    }
}

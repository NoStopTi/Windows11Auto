function Enable-SecurityServices {
    param([switch]$WhatIf)

    Write-Log "=== Servicos de seguranca ==="

    $services = @(
        @{ Name = 'WdNisSvc';             Label = 'Windows Defender Network Inspection Service'; StartType = 'Manual' }
        @{ Name = 'SecurityHealthService'; Label = 'Windows Security Health Service';             StartType = 'Manual' }
        @{ Name = 'wscsvc';               Label = 'Security Center Service';                      StartType = 'Automatic' }
        @{ Name = 'WdFilter';             Label = 'Windows Defender Mini-Filter Driver';           StartType = 'Automatic' }
    )

    foreach ($svc in $services) {
        try {
            if ($WhatIf) {
                Write-Log "[WHATIF] Ativaria servico: $($svc.Label)"
                Add-Result 'Servicos' $svc.Label 'WHATIF'
                continue
            }
            $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if ($s) {
                try { Set-Service -Name $svc.Name -StartupType $svc.StartType -ErrorAction Stop } catch {}
                try { Start-Service -Name $svc.Name -ErrorAction Stop } catch {}
                Write-Log "Ativado: $($svc.Label) (StartupType: $($svc.StartType))" -Level 'OK'
                Add-Result 'Servicos' $svc.Label 'ENABLED'
            }
            else {
                Write-Log "Servico nao encontrado: $($svc.Name)" -Level 'WARN'
                Add-Result 'Servicos' $svc.Label 'NOT_FOUND'
            }
        }
        catch {
            Write-Log "Falha ao ativar servico $($svc.Name): $_" -Level 'ERROR'
            Add-Result 'Servicos' $svc.Label 'FAILED' $_.Exception.Message
        }
    }
}

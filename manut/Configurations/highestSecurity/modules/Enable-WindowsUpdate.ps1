function Enable-WindowsUpdateSecurity {
    param([switch]$WhatIf)

    Write-Log "=== Windows Update - Restaurar atualizacoes automaticas ==="

    $keysToRemove = @(
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
            Name  = 'NoAutoUpdate'
            Label = 'Restaurar atualizacoes automaticas'
        }
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            Name  = 'DeferQualityUpdates'
            Label = 'Remover adiamento de atualizacoes de qualidade'
        }
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            Name  = 'DeferQualityUpdatesPeriodInDays'
            Label = 'Remover atraso de atualizacoes de qualidade'
        }
    )

    foreach ($r in $keysToRemove) {
        if ($WhatIf) {
            Write-Log "[WHATIF] Restauraria: $($r.Label)"
            Add-Result 'Windows Update' $r.Label 'WHATIF'
            continue
        }
        $ok = Remove-RegistryValue $r.Path $r.Name
        if ($ok) {
            Write-Log "Restaurado: $($r.Label)" -Level 'OK'
            Add-Result 'Windows Update' $r.Label 'ENABLED'
        }
        else {
            Add-Result 'Windows Update' $r.Label 'FAILED'
        }
    }
}

function Disable-WindowsUpdateSecurity {
    param([switch]$WhatIf)

    Write-Log "=== Windows Update - Atrasar atualizacoes de seguranca ==="

    $settings = @(
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
            Name  = 'NoAutoUpdate'
            Value = 1
            Label = 'Desativar atualizacoes automaticas'
        }
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            Name  = 'DeferQualityUpdates'
            Value = 1
            Label = 'Adiar atualizacoes de qualidade'
        }
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            Name  = 'DeferQualityUpdatesPeriodInDays'
            Value = 30
            Label = 'Atraso de atualizacoes de qualidade (30 dias)'
        }
    )

    foreach ($s in $settings) {
        if ($WhatIf) {
            Write-Log "[WHATIF] Configuraria: $($s.Label)"
            Add-Result 'Windows Update' $s.Label 'WHATIF'
            continue
        }
        $ok = Set-RegistryValue $s.Path $s.Name $s.Value
        if ($ok) {
            Write-Log "Configurado: $($s.Label)" -Level 'OK'
            Add-Result 'Windows Update' $s.Label 'DISABLED'
        }
        else {
            Add-Result 'Windows Update' $s.Label 'FAILED'
        }
    }
}

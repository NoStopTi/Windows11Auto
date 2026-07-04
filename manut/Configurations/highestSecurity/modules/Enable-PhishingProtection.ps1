function Enable-PhishingProtection {
    param([switch]$WhatIf)

    Write-Log "=== Protecao contra Phishing ==="

    $basePath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WTDS\Components'
    $settings = @(
        @{ Name = 'ServiceEnabled';      Value = 1; Label = 'Protecao contra phishing (servico)' }
        @{ Name = 'NotifyMalicious';     Value = 1; Label = 'Aviso sobre sites/apps mal-intencionados' }
        @{ Name = 'NotifyPasswordReuse'; Value = 1; Label = 'Aviso sobre reutilizacao de senha' }
        @{ Name = 'NotifyUnsafeApp';     Value = 1; Label = 'Aviso sobre armazenamento inseguro de senha' }
        @{ Name = 'CaptureThreatWindow'; Value = 1; Label = 'Coleta automatica de conteudo para analise' }
    )

    foreach ($s in $settings) {
        if ($WhatIf) {
            Write-Log "[WHATIF] Ativaria: $($s.Label)"
            Add-Result 'Phishing' $s.Label 'WHATIF'
            continue
        }
        $ok = Set-RegistryValue $basePath $s.Name $s.Value
        if ($ok) {
            Write-Log "Ativado: $($s.Label)" -Level 'OK'
            Add-Result 'Phishing' $s.Label 'ENABLED'
        }
        else {
            Add-Result 'Phishing' $s.Label 'FAILED'
        }
    }
}

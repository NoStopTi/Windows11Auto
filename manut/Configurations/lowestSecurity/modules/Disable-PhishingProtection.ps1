function Disable-PhishingProtection {
    param([switch]$WhatIf)

    Write-Log "=== Protecao contra Phishing ==="

    $basePath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WTDS\Components'
    $settings = @(
        @{ Name = 'ServiceEnabled';      Value = 0; Label = 'Protecao contra phishing (servico)' }
        @{ Name = 'NotifyMalicious';     Value = 0; Label = 'Aviso sobre sites/apps mal-intencionados' }
        @{ Name = 'NotifyPasswordReuse'; Value = 0; Label = 'Aviso sobre reutilizacao de senha' }
        @{ Name = 'NotifyUnsafeApp';     Value = 0; Label = 'Aviso sobre armazenamento inseguro de senha' }
        @{ Name = 'CaptureThreatWindow'; Value = 0; Label = 'Coleta automatica de conteudo para analise' }
    )

    foreach ($s in $settings) {
        if ($WhatIf) {
            Write-Log "[WHATIF] Desativaria: $($s.Label)"
            Add-Result 'Phishing' $s.Label 'WHATIF'
            continue
        }
        $ok = Set-RegistryValue $basePath $s.Name $s.Value
        if ($ok) {
            Write-Log "Desativado: $($s.Label)" -Level 'OK'
            Add-Result 'Phishing' $s.Label 'DISABLED'
        }
        else {
            Add-Result 'Phishing' $s.Label 'FAILED'
        }
    }
}

function Enable-WindowsFirewall {
    param([switch]$WhatIf)

    Write-Log "=== Windows Firewall ==="

    $profiles = @('Domain', 'Private', 'Public')
    foreach ($p in $profiles) {
        try {
            if ($WhatIf) {
                Write-Log "[WHATIF] Ativaria Firewall perfil: $p"
                Add-Result 'Firewall' "Perfil $p" 'WHATIF'
                continue
            }
            Set-NetFirewallProfile -Profile $p -Enabled True
            Write-Log "Ativado: Firewall perfil $p" -Level 'OK'
            Add-Result 'Firewall' "Perfil $p" 'ENABLED'
        }
        catch {
            Write-Log "Falha ao ativar Firewall $p : $_" -Level 'ERROR'
            Add-Result 'Firewall' "Perfil $p" 'FAILED' $_.Exception.Message
        }
    }
}

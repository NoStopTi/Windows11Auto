function Disable-WindowsFirewall {
    param([switch]$WhatIf)

    Write-Log "=== Windows Firewall ==="

    $profiles = @('Domain', 'Private', 'Public')
    foreach ($p in $profiles) {
        try {
            if ($WhatIf) {
                Write-Log "[WHATIF] Desativaria Firewall perfil: $p"
                Add-Result 'Firewall' "Perfil $p" 'WHATIF'
                continue
            }
            Set-NetFirewallProfile -Profile $p -Enabled False
            Write-Log "Desativado: Firewall perfil $p" -Level 'OK'
            Add-Result 'Firewall' "Perfil $p" 'DISABLED'
        }
        catch {
            Write-Log "Falha ao desativar Firewall $p : $_" -Level 'ERROR'
            Add-Result 'Firewall' "Perfil $p" 'FAILED' $_.Exception.Message
        }
    }
}

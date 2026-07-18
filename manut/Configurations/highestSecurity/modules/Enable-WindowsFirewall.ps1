function Enable-WindowsFirewall {
    param([switch]$WhatIf)

    Write-Log "=== Windows Firewall ==="

    $profiles = @('Domain', 'Private', 'Public')
    foreach ($p in $profiles) {
        try {
            if ($WhatIf) {
                Write-Log "[WHATIF] Would enable Firewall profile: $p"
                Add-Result 'Firewall' "Profile $p" 'WHATIF'
                continue
            }
            Set-NetFirewallProfile -Profile $p -Enabled True
            Write-Log "Enabled: Firewall profile $p" -Level 'OK'
            Add-Result 'Firewall' "Profile $p" 'ENABLED'
        }
        catch {
            Write-Log "Failed to enable Firewall $p : $_" -Level 'ERROR'
            Add-Result 'Firewall' "Profile $p" 'FAILED' $_.Exception.Message
        }
    }
}

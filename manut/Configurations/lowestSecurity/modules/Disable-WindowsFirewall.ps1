function Disable-WindowsFirewall {
    param([switch]$WhatIf)

    Write-Log "=== Windows Firewall ==="

    $profiles = @('Domain', 'Private', 'Public')
    foreach ($p in $profiles) {
        try {
            if ($WhatIf) {
                Write-Log "[WHATIF] Would disable Firewall profile: $p"
                Add-Result 'Firewall' "Profile $p" 'WHATIF'
                continue
            }
            Set-NetFirewallProfile -Profile $p -Enabled False
            Write-Log "Disabled: Firewall profile $p" -Level 'OK'
            Add-Result 'Firewall' "Profile $p" 'DISABLED'
        }
        catch {
            Write-Log "Failed to disable Firewall $p : $_" -Level 'ERROR'
            Add-Result 'Firewall' "Profile $p" 'FAILED' $_.Exception.Message
        }
    }
}

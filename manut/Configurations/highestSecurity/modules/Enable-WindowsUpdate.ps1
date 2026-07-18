function Enable-WindowsUpdateSecurity {
    param([switch]$WhatIf)

    Write-Log "=== Windows Update - Restore automatic updates ==="

    $keysToRemove = @(
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
            Name  = 'NoAutoUpdate'
            Label = 'Restore automatic updates'
        }
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            Name  = 'DeferQualityUpdates'
            Label = 'Remove quality update deferral'
        }
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            Name  = 'DeferQualityUpdatesPeriodInDays'
            Label = 'Remove quality update delay'
        }
    )

    foreach ($r in $keysToRemove) {
        if ($WhatIf) {
            Write-Log "[WHATIF] Would restore: $($r.Label)"
            Add-Result 'Windows Update' $r.Label 'WHATIF'
            continue
        }
        $ok = Remove-RegistryValue $r.Path $r.Name
        if ($ok) {
            Write-Log "Restored: $($r.Label)" -Level 'OK'
            Add-Result 'Windows Update' $r.Label 'ENABLED'
        }
        else {
            Add-Result 'Windows Update' $r.Label 'FAILED'
        }
    }
}

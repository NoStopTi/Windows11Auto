function Disable-WindowsUpdateSecurity {
    param([switch]$WhatIf)

    Write-Log "=== Windows Update - Delay security updates ==="

    $settings = @(
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
            Name  = 'NoAutoUpdate'
            Value = 1
            Label = 'Disable automatic updates'
        }
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            Name  = 'DeferQualityUpdates'
            Value = 1
            Label = 'Defer quality updates'
        }
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
            Name  = 'DeferQualityUpdatesPeriodInDays'
            Value = 30
            Label = 'Quality update delay (30 days)'
        }
    )

    foreach ($s in $settings) {
        if ($WhatIf) {
            Write-Log "[WHATIF] Would configure: $($s.Label)"
            Add-Result 'Windows Update' $s.Label 'WHATIF'
            continue
        }
        $ok = Set-RegistryValue $s.Path $s.Name $s.Value
        if ($ok) {
            Write-Log "Configured: $($s.Label)" -Level 'OK'
            Add-Result 'Windows Update' $s.Label 'DISABLED'
        }
        else {
            Add-Result 'Windows Update' $s.Label 'FAILED'
        }
    }
}

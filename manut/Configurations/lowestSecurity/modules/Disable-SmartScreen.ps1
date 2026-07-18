function Disable-SmartScreen {
    param([switch]$WhatIf)

    Write-Log "=== SmartScreen and Reputation Protection ==="

    $regSettings = @(
        @{
            Path  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'
            Name  = 'SmartScreenEnabled'
            Value = 'Off'
            Type  = 'String'
            Label = 'SmartScreen - Check apps and files'
        }
        @{
            Path  = 'HKCU:\SOFTWARE\Microsoft\Edge\SmartScreenEnabled'
            Name  = '(Default)'
            Value = 0
            Type  = 'DWord'
            Label = 'SmartScreen for Microsoft Edge'
        }
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
            Name  = 'SmartScreenEnabled'
            Value = 0
            Type  = 'DWord'
            Label = 'SmartScreen for Microsoft Edge (GPO)'
        }
        @{
            Path  = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost'
            Name  = 'EnableWebContentEvaluation'
            Value = 0
            Type  = 'DWord'
            Label = 'SmartScreen for Microsoft Store apps'
        }
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
            Name  = 'EnableSmartScreen'
            Value = 0
            Type  = 'DWord'
            Label = 'SmartScreen via Group Policy'
        }
    )

    foreach ($r in $regSettings) {
        if ($WhatIf) {
            Write-Log "[WHATIF] Would disable: $($r.Label)"
            Add-Result 'SmartScreen' $r.Label 'WHATIF'
            continue
        }
        if ($r.Name -eq '(Default)') {
            $ok = Set-RegistryDefaultValue $r.Path $r.Value
            if ($ok) {
                Write-Log "Disabled: $($r.Label)" -Level 'OK'
                Add-Result 'SmartScreen' $r.Label 'DISABLED'
            }
            else {
                Add-Result 'SmartScreen' $r.Label 'FAILED'
            }
        }
        else {
            $ok = Set-RegistryValue $r.Path $r.Name $r.Value $r.Type
            if ($ok) {
                Write-Log "Disabled: $($r.Label)" -Level 'OK'
                Add-Result 'SmartScreen' $r.Label 'DISABLED'
            }
            else {
                Add-Result 'SmartScreen' $r.Label 'FAILED'
            }
        }
    }
}

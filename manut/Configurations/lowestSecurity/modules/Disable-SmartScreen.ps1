function Disable-SmartScreen {
    param([switch]$WhatIf)

    Write-Log "=== SmartScreen e Protecao de Reputacao ==="

    $regSettings = @(
        @{
            Path  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'
            Name  = 'SmartScreenEnabled'
            Value = 'Off'
            Type  = 'String'
            Label = 'SmartScreen - Verificar aplicativos e arquivos'
        }
        @{
            Path  = 'HKCU:\SOFTWARE\Microsoft\Edge\SmartScreenEnabled'
            Name  = '(Default)'
            Value = 0
            Type  = 'DWord'
            Label = 'SmartScreen para Microsoft Edge'
        }
        @{
            Path  = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
            Name  = 'SmartScreenEnabled'
            Value = 0
            Type  = 'DWord'
            Label = 'SmartScreen para Microsoft Edge (GPO)'
        }
        @{
            Path  = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost'
            Name  = 'EnableWebContentEvaluation'
            Value = 0
            Type  = 'DWord'
            Label = 'SmartScreen para apps da Microsoft Store'
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
            Write-Log "[WHATIF] Desativaria: $($r.Label)"
            Add-Result 'SmartScreen' $r.Label 'WHATIF'
            continue
        }
        if ($r.Name -eq '(Default)') {
            $ok = Set-RegistryDefaultValue $r.Path $r.Value
            if ($ok) {
                Write-Log "Desativado: $($r.Label)" -Level 'OK'
                Add-Result 'SmartScreen' $r.Label 'DISABLED'
            }
            else {
                Add-Result 'SmartScreen' $r.Label 'FAILED'
            }
        }
        else {
            $ok = Set-RegistryValue $r.Path $r.Name $r.Value $r.Type
            if ($ok) {
                Write-Log "Desativado: $($r.Label)" -Level 'OK'
                Add-Result 'SmartScreen' $r.Label 'DISABLED'
            }
            else {
                Add-Result 'SmartScreen' $r.Label 'FAILED'
            }
        }
    }
}

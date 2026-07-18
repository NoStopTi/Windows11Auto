function Disable-UAC {
    param([switch]$WhatIf)

    Write-Log "=== User Account Control (UAC) ==="

    $uacPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $settings = @(
        @{ Name = 'EnableLUA';                  Value = 0; Label = 'UAC (EnableLUA)' }
        @{ Name = 'ConsentPromptBehaviorAdmin'; Value = 0; Label = 'UAC Consent Prompt (Admin)' }
        @{ Name = 'PromptOnSecureDesktop';      Value = 0; Label = 'UAC Secure Desktop' }
        @{ Name = 'EnableInstallerDetection';   Value = 0; Label = 'UAC Installer Detection' }
        @{ Name = 'EnableVirtualization';       Value = 0; Label = 'UAC Virtualization' }
    )

    foreach ($s in $settings) {
        if ($WhatIf) {
            Write-Log "[WHATIF] Would disable: $($s.Label)"
            Add-Result 'UAC' $s.Label 'WHATIF'
            continue
        }
        $ok = Set-RegistryValue $uacPath $s.Name $s.Value
        if ($ok) {
            Write-Log "Disabled: $($s.Label)" -Level 'OK'
            Add-Result 'UAC' $s.Label 'DISABLED'
        }
        else {
            Add-Result 'UAC' $s.Label 'FAILED'
        }
    }
}

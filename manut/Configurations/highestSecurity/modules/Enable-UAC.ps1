function Enable-UAC {
    param([switch]$WhatIf)

    Write-Log "=== User Account Control (UAC) ==="

    $uacPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $settings = @(
        @{ Name = 'EnableLUA';                  Value = 1; Label = 'UAC (EnableLUA)' }
        @{ Name = 'ConsentPromptBehaviorAdmin'; Value = 5; Label = 'UAC Consent Prompt (Admin - Prompt for consent)' }
        @{ Name = 'PromptOnSecureDesktop';      Value = 1; Label = 'UAC Secure Desktop' }
        @{ Name = 'EnableInstallerDetection';   Value = 1; Label = 'UAC Installer Detection' }
        @{ Name = 'EnableVirtualization';       Value = 1; Label = 'UAC Virtualization' }
    )

    foreach ($s in $settings) {
        if ($WhatIf) {
            Write-Log "[WHATIF] Would enable: $($s.Label)"
            Add-Result 'UAC' $s.Label 'WHATIF'
            continue
        }
        $ok = Set-RegistryValue $uacPath $s.Name $s.Value
        if ($ok) {
            Write-Log "Enabled: $($s.Label)" -Level 'OK'
            Add-Result 'UAC' $s.Label 'ENABLED'
        }
        else {
            Add-Result 'UAC' $s.Label 'FAILED'
        }
    }
}

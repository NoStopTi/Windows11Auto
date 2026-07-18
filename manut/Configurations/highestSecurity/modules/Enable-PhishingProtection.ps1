function Enable-PhishingProtection {
    param([switch]$WhatIf)

    Write-Log "=== Phishing Protection ==="

    $basePath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WTDS\Components'
    $settings = @(
        @{ Name = 'ServiceEnabled';      Value = 1; Label = 'Phishing protection (service)' }
        @{ Name = 'NotifyMalicious';     Value = 1; Label = 'Warning about malicious sites/apps' }
        @{ Name = 'NotifyPasswordReuse'; Value = 1; Label = 'Warning about password reuse' }
        @{ Name = 'NotifyUnsafeApp';     Value = 1; Label = 'Warning about unsafe password storage' }
        @{ Name = 'CaptureThreatWindow'; Value = 1; Label = 'Automatic content capture for analysis' }
    )

    foreach ($s in $settings) {
        if ($WhatIf) {
            Write-Log "[WHATIF] Would enable: $($s.Label)"
            Add-Result 'Phishing' $s.Label 'WHATIF'
            continue
        }
        $ok = Set-RegistryValue $basePath $s.Name $s.Value
        if ($ok) {
            Write-Log "Enabled: $($s.Label)" -Level 'OK'
            Add-Result 'Phishing' $s.Label 'ENABLED'
        }
        else {
            Add-Result 'Phishing' $s.Label 'FAILED'
        }
    }
}

function Enable-DevDriveProtection {
    param([switch]$WhatIf)

    Write-Log "=== Dev Drive Protection ==="

    if ($WhatIf) {
        Write-Log "[WHATIF] Would enable: Dev Drive Protection"
        Add-Result 'Dev Drive' 'Dev Drive Protection' 'WHATIF'
        return
    }

    try {
        $ok = Remove-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection' 'DisableAsyncScanOnOpen'
        if ($ok) {
            Write-Log "Enabled: Dev Drive Protection (restored default)" -Level 'OK'
            Add-Result 'Dev Drive' 'Dev Drive Protection' 'ENABLED'
        }
    }
    catch {
        Write-Log "Dev Drive Protection failure: $_" -Level 'ERROR'
        Add-Result 'Dev Drive' 'Dev Drive Protection' 'FAILED' $_.Exception.Message
    }
}

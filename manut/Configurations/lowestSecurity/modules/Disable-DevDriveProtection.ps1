function Disable-DevDriveProtection {
    param([switch]$WhatIf)

    Write-Log "=== Dev Drive Protection ==="

    if ($WhatIf) {
        Write-Log "[WHATIF] Would disable: Dev Drive Protection"
        Add-Result 'Dev Drive' 'Dev Drive Protection' 'WHATIF'
        return
    }

    try {
        $ok = Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection' 'DisableAsyncScanOnOpen' 1
        if ($ok) {
            Write-Log "Disabled: Dev Drive Protection (async scan)" -Level 'OK'
            Add-Result 'Dev Drive' 'Dev Drive Protection' 'DISABLED'
        }
    }
    catch {
        Write-Log "Dev Drive Protection failure: $_" -Level 'ERROR'
        Add-Result 'Dev Drive' 'Dev Drive Protection' 'FAILED' $_.Exception.Message
    }
}

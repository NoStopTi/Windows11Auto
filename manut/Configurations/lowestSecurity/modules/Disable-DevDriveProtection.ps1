function Disable-DevDriveProtection {
    param([switch]$WhatIf)

    Write-Log "=== Dev Drive Protection ==="

    if ($WhatIf) {
        Write-Log "[WHATIF] Desativaria: Dev Drive Protection"
        Add-Result 'Dev Drive' 'Protecao de Unidade de Desenvolvimento' 'WHATIF'
        return
    }

    try {
        $ok = Set-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection' 'DisableAsyncScanOnOpen' 1
        if ($ok) {
            Write-Log "Desativado: Dev Drive Protection (async scan)" -Level 'OK'
            Add-Result 'Dev Drive' 'Protecao de Unidade de Desenvolvimento' 'DISABLED'
        }
    }
    catch {
        Write-Log "Falha Dev Drive Protection: $_" -Level 'ERROR'
        Add-Result 'Dev Drive' 'Protecao de Unidade de Desenvolvimento' 'FAILED' $_.Exception.Message
    }
}

function Enable-DevDriveProtection {
    param([switch]$WhatIf)

    Write-Log "=== Dev Drive Protection ==="

    if ($WhatIf) {
        Write-Log "[WHATIF] Ativaria: Dev Drive Protection"
        Add-Result 'Dev Drive' 'Protecao de Unidade de Desenvolvimento' 'WHATIF'
        return
    }

    try {
        $ok = Remove-RegistryValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection' 'DisableAsyncScanOnOpen'
        if ($ok) {
            Write-Log "Ativado: Dev Drive Protection (restaurado padrao)" -Level 'OK'
            Add-Result 'Dev Drive' 'Protecao de Unidade de Desenvolvimento' 'ENABLED'
        }
    }
    catch {
        Write-Log "Falha Dev Drive Protection: $_" -Level 'ERROR'
        Add-Result 'Dev Drive' 'Protecao de Unidade de Desenvolvimento' 'FAILED' $_.Exception.Message
    }
}

function Update-DefenderSignatures {
    param([switch]$WhatIf)

    Write-Log "=== Atualizacao de assinaturas do Defender ==="

    if ($WhatIf) {
        Write-Log "[WHATIF] Atualizaria assinaturas do Defender"
        Add-Result 'Assinaturas' 'Update-MpSignature' 'WHATIF'
        return
    }

    try {
        Update-MpSignature
        Write-Log "Assinaturas do Defender atualizadas com sucesso" -Level 'OK'
        Add-Result 'Assinaturas' 'Update-MpSignature' 'UPDATED'
    }
    catch {
        Write-Log "Falha ao atualizar assinaturas: $_" -Level 'ERROR'
        Add-Result 'Assinaturas' 'Update-MpSignature' 'FAILED' $_.Exception.Message
    }
}

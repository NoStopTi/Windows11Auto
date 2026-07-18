function Update-DefenderSignatures {
    param([switch]$WhatIf)

    Write-Log "=== Defender signature update ==="

    if ($WhatIf) {
        Write-Log "[WHATIF] Would update Defender signatures"
        Add-Result 'Signatures' 'Update-MpSignature' 'WHATIF'
        return
    }

    try {
        Update-MpSignature
        Write-Log "Defender signatures updated successfully" -Level 'OK'
        Add-Result 'Signatures' 'Update-MpSignature' 'UPDATED'
    }
    catch {
        Write-Log "Failed to update signatures: $_" -Level 'ERROR'
        Add-Result 'Signatures' 'Update-MpSignature' 'FAILED' $_.Exception.Message
    }
}

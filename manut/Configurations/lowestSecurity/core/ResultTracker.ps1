$script:ResultSummary = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-Result {
    param(
        [string]$Category,
        [string]$Setting,
        [string]$Status,
        [string]$Detail = ''
    )
    $script:ResultSummary.Add([PSCustomObject]@{
        Category = $Category
        Setting  = $Setting
        Status   = $Status
        Detail   = $Detail
    })
}

function Get-ResultSummary { return $script:ResultSummary }

function Show-ResultSummary {
    $results = Get-ResultSummary

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "                    RESUMO DA EXECUCAO" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow

    $results | Format-Table -AutoSize Category, Setting, Status, Detail

    $disabled = @($results | Where-Object Status -eq 'DISABLED').Count
    $failed   = @($results | Where-Object Status -eq 'FAILED').Count
    $whatif   = @($results | Where-Object Status -eq 'WHATIF').Count
    $total    = @($results).Count

    Write-Host ""
    Write-Log "Total: $total | Desativados: $disabled | Falhas: $failed | WhatIf: $whatif"
    Write-Log "Log salvo em: $(Get-LogFilePath)"

    if ($failed -gt 0) {
        Write-Log "Verifique se Tamper Protection esta desativada e execute novamente como Administrador." -Level 'WARN'
    }
}

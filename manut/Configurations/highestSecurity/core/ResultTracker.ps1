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
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "                    RESUMO DA EXECUCAO" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green

    $results | Format-Table -AutoSize Category, Setting, Status, Detail

    $enabled = @($results | Where-Object Status -eq 'ENABLED').Count
    $updated = @($results | Where-Object Status -eq 'UPDATED').Count
    $failed  = @($results | Where-Object Status -eq 'FAILED').Count
    $whatif  = @($results | Where-Object Status -eq 'WHATIF').Count
    $total   = @($results).Count

    Write-Host ""
    Write-Log "Total: $total | Ativados: $enabled | Atualizados: $updated | Falhas: $failed | WhatIf: $whatif"
    Write-Log "Log salvo em: $(Get-LogFilePath)"

    if ($failed -gt 0) {
        Write-Log "Algumas configuracoes falharam. Verifique o log e execute novamente como Administrador." -Level 'WARN'
    }
}

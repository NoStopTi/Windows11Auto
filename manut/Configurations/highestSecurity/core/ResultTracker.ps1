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
    Write-Host "                    EXECUTION SUMMARY" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green

    $results | Format-Table -AutoSize Category, Setting, Status, Detail

    $enabled = @($results | Where-Object Status -eq 'ENABLED').Count
    $updated = @($results | Where-Object Status -eq 'UPDATED').Count
    $failed  = @($results | Where-Object Status -eq 'FAILED').Count
    $whatif  = @($results | Where-Object Status -eq 'WHATIF').Count
    $total   = @($results).Count

    Write-Host ""
    Write-Log "Total: $total | Enabled: $enabled | Updated: $updated | Failed: $failed | WhatIf: $whatif"
    Write-Log "Log saved to: $(Get-LogFilePath)"

    if ($failed -gt 0) {
        Write-Log "Some settings failed. Check the log and run again as Administrator." -Level 'WARN'
    }
}

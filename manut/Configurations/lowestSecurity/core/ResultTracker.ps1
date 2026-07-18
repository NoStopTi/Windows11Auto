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
    Write-Host "                    EXECUTION SUMMARY" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow

    $results | Format-Table -AutoSize Category, Setting, Status, Detail

    $disabled = @($results | Where-Object Status -eq 'DISABLED').Count
    $failed   = @($results | Where-Object Status -eq 'FAILED').Count
    $whatif   = @($results | Where-Object Status -eq 'WHATIF').Count
    $total    = @($results).Count

    Write-Host ""
    Write-Log "Total: $total | Disabled: $disabled | Failed: $failed | WhatIf: $whatif"
    Write-Log "Log saved to: $(Get-LogFilePath)"

    if ($failed -gt 0) {
        Write-Log "Check that Tamper Protection is disabled and run again as Administrator." -Level 'WARN'
    }
}

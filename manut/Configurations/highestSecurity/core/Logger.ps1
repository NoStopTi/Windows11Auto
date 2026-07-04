$script:LogFile = Join-Path $PSScriptRoot "..\enable-security_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $color = switch ($Level) {
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'OK'    { 'Green' }
        default { 'Cyan' }
    }
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $entry -ForegroundColor $color
    Add-Content -Path $script:LogFile -Value $entry
}

function Get-LogFilePath { return $script:LogFile }

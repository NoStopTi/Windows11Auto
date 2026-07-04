class Logger {
    [string] $LogPath

    Logger([string] $logDirectory) {
        if (-not (Test-Path $logDirectory)) {
            New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
        }
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $this.LogPath = Join-Path $logDirectory "start_$timestamp.txt"
    }

    [void] Info([string] $message) {
        $this.WriteEntry("INFO", $message)
    }

    [void] Warn([string] $message) {
        $this.WriteEntry("WARN", $message)
        Write-Warning $message
    }

    [void] Error([string] $message) {
        $this.WriteEntry("ERROR", $message)
        Write-Host $message -ForegroundColor Red
    }

    [void] Success([string] $message) {
        $this.WriteEntry("OK", $message)
        Write-Host $message -ForegroundColor Green
    }

    hidden [void] WriteEntry([string] $level, [string] $message) {
        $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $level, $message
        Add-Content -Path $this.LogPath -Value $line -ErrorAction SilentlyContinue
        if ($level -notin @("WARN", "ERROR")) {
            Write-Host $line
        }
    }
}

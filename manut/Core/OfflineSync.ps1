function Get-PendriveManutRoot {
    [OutputType([string])]
    param([string] $RelativePath = "manut")

    foreach ($code in ([char]'B')..([char]'Z')) {
        $letter = [char] $code
        if ($letter -eq 'C') { continue }

        $candidate = "$letter`:\$RelativePath"
        if (Test-Path $candidate) {
            return "$letter`:\"
        }
    }

    return $null
}

function Sync-OfflineInstallers {
    param(
        [Logger]              $Log,
        [AppConfig]           $Config,
        [PackageDefinition[]] $Packages,
        [int]                 $MaxAgeDays = 30
    )

    $pendriveRoot = Get-PendriveManutRoot
    if ($pendriveRoot) {
        $Log.Info("Pendrive found at $pendriveRoot")
    }
    else {
        $Log.Warn("No pendrive found. Refreshed installers will only be updated locally.")
    }

    foreach ($pkg in $Packages) {
        if (-not $pkg.DownloadUrl) { continue }

        $isStale = $true
        if (Test-Path $pkg.OfflineFile) {
            $ageDays = ((Get-Date) - (Get-Item $pkg.OfflineFile).LastWriteTime).TotalDays
            $isStale = $ageDays -gt $MaxAgeDays
        }

        if (-not $isStale) { continue }

        $Log.Info("$($pkg.Name): offline file missing or older than $MaxAgeDays days. Downloading update...")
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $parentDir = Split-Path $pkg.OfflineFile -Parent
            if (-not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            Invoke-WebRequest -Uri $pkg.DownloadUrl -OutFile $pkg.OfflineFile -UseBasicParsing
            $Log.Success("$($pkg.Name): local offline file updated.")
        }
        catch {
            $Log.Error("$($pkg.Name): failed to update offline file: $_")
            continue
        }

        if (-not $pendriveRoot) { continue }

        try {
            $pendriveFile = $pkg.OfflineFile -replace [regex]::Escape($Config.BasePath), (Join-Path $pendriveRoot "manut")
            $pendriveDir  = Split-Path $pendriveFile -Parent
            if (-not (Test-Path $pendriveDir)) {
                New-Item -ItemType Directory -Path $pendriveDir -Force | Out-Null
            }
            Copy-Item -Path $pkg.OfflineFile -Destination $pendriveFile -Force
            $Log.Success("$($pkg.Name): pendrive offline file updated at $pendriveFile.")
        }
        catch {
            $Log.Error("$($pkg.Name): failed to update pendrive offline file: $_")
        }
    }
}

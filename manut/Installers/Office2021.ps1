function Install-Office2021 {
    param(
        [Logger]    $Log,
        [AppConfig] $Config
    )

    $offlineZip = $Config.OfflineFile("Office2021W10.zip")
    $setupDir   = Join-Path $Config.OfflinePath "Office2021W10"
    $setupExe   = Join-Path $setupDir "setup.exe"
    $configXml  = Join-Path $setupDir "configuration.xml"

    $Log.Info("=== Office 2021 ===")

    if (Test-Path $offlineZip) {
        $Log.Info("Offline package found. Extracting...")
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($offlineZip, $Config.OfflinePath)
        }
        catch {
            $Log.Warn("Extraction may have already been done: $_")
        }
    }

    if (-not (Test-Path $setupExe)) {
        $Log.Error("Office setup.exe not found at: $setupDir")
        return
    }

    if (-not (Test-Path (Join-Path $setupDir "Office"))) {
        $Log.Info("Office files not found. Downloading via ODT...")
        Start-Process -FilePath $setupExe -ArgumentList "/download `"$configXml`"" -Wait
        $Log.Success("Office download complete.")
    }

    $Log.Info("Installing Office 2021...")
    Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configXml`"" -Wait
    $Log.Success("Office 2021 installed successfully.")
}

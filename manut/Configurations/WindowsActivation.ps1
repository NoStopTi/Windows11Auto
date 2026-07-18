function Start-WindowsAndOfficeActivation {
    param(
        [Logger]    $Log,
        [AppConfig] $Config
    )

    $kmsScript = Join-Path $Config.BasePath "Auto\Ativador\W11Office2016\KMS_Suite.cmd"

    if (-not (Test-Path $kmsScript)) {
        $Log.Warn("Activation script not found: $kmsScript")
        return
    }

    $Log.Info("Running Windows/Office activation...")
    Start-Process -FilePath $kmsScript
    $Log.Success("Activation started.")
}

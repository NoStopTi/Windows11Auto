function Start-WindowsAndOfficeActivation {
    param(
        [Logger]    $Log,
        [AppConfig] $Config
    )

    $kmsScript = Join-Path $Config.BasePath "Auto\Ativador\W11Office2016\KMS_Suite.cmd"

    if (-not (Test-Path $kmsScript)) {
        $Log.Warn("Script de ativacao nao encontrado: $kmsScript")
        return
    }

    $Log.Info("Executando ativacao Windows/Office...")
    Start-Process -FilePath $kmsScript
    $Log.Success("Ativacao iniciada.")
}

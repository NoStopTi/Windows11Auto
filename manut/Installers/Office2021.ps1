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
        $Log.Info("Pacote offline encontrado. Extraindo...")
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($offlineZip, $Config.OfflinePath)
        }
        catch {
            $Log.Warn("Extracao pode ja ter sido feita: $_")
        }
    }

    if (-not (Test-Path $setupExe)) {
        $Log.Error("setup.exe do Office nao encontrado em: $setupDir")
        return
    }

    if (-not (Test-Path (Join-Path $setupDir "Office"))) {
        $Log.Info("Arquivos do Office nao encontrados. Fazendo download via ODT...")
        Start-Process -FilePath $setupExe -ArgumentList "/download `"$configXml`"" -Wait
        $Log.Success("Download do Office concluido.")
    }

    $Log.Info("Instalando Office 2021...")
    Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configXml`"" -Wait
    $Log.Success("Office 2021 instalado com sucesso.")
}

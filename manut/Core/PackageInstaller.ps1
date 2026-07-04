class PackageInstaller {
    [Logger]    $Log
    [AppConfig] $Config

    PackageInstaller([Logger] $logger, [AppConfig] $config) {
        $this.Log = $logger
        $this.Config = $config
    }

    [bool] HasInternet() {
        return (Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue)
    }

    [bool] OfflineExists([PackageDefinition] $pkg) {
        return (Test-Path $pkg.OfflineFile)
    }

    [void] Install([PackageDefinition] $pkg) {
        $this.Log.Info("=== $($pkg.Name) ===")

        if ($this.OfflineExists($pkg)) {
            $this.Log.Info("Instalador offline encontrado: $($pkg.OfflineFile)")
        }
        elseif ($pkg.DownloadUrl -and $this.HasInternet()) {
            $this.Download($pkg)
        }
        else {
            $this.Log.Error("$($pkg.Name): sem instalador offline e sem internet. Pulando.")
            return
        }

        if ($pkg.IsArchive) {
            $this.ExtractArchive($pkg)
        }

        $this.Execute($pkg)
    }

    hidden [void] Download([PackageDefinition] $pkg) {
        $this.Log.Info("Baixando $($pkg.Name)...")
        $parentDir = Split-Path $pkg.OfflineFile -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $pkg.DownloadUrl -OutFile $pkg.OfflineFile -UseBasicParsing
            $this.Log.Success("Download concluido: $($pkg.Name)")
        }
        catch {
            $this.Log.Error("Falha no download de $($pkg.Name): $_")
            throw
        }
    }

    hidden [void] ExtractArchive([PackageDefinition] $pkg) {
        $targetDir = Split-Path $pkg.OfflineFile -Parent
        $this.Log.Info("Extraindo $($pkg.OfflineFile)...")
        try {
            Expand-Archive -Path $pkg.OfflineFile -DestinationPath $targetDir -Force
            $this.Log.Success("Extracao concluida: $($pkg.Name)")
        }
        catch {
            $this.Log.Warn("Extracao pode ja ter sido feita ou falhou: $_")
        }
    }

    hidden [void] Execute([PackageDefinition] $pkg) {
        $installerPath = $pkg.InstallerPath
        if (-not (Test-Path $installerPath)) {
            $this.Log.Error("Instalador nao encontrado: $installerPath")
            return
        }

        $ext = [System.IO.Path]::GetExtension($installerPath).ToLower()
        $this.Log.Info("Instalando $($pkg.Name)...")

        try {
            switch ($ext) {
                ".exe" {
                    $splat = @{ FilePath = $installerPath }
                    if ($pkg.SilentArgs) { $splat.ArgumentList = $pkg.SilentArgs }
                    if ($pkg.WaitForExit) { $splat.Wait = $true }
                    Start-Process @splat
                }
                ".msi" {
                    $msiArgs = "/I `"$installerPath`" $($pkg.SilentArgs) /qn /norestart"
                    $splat = @{ FilePath = "msiexec.exe"; ArgumentList = $msiArgs }
                    if ($pkg.WaitForExit) { $splat.Wait = $true }
                    Start-Process @splat
                }
                ".bat" {
                    $splat = @{ FilePath = "cmd.exe"; ArgumentList = "/c `"$installerPath`"" }
                    if ($pkg.WaitForExit) { $splat.Wait = $true }
                    Start-Process @splat
                }
                default {
                    $this.Log.Error("Extensao nao suportada: $ext")
                    return
                }
            }
            $this.Log.Success("$($pkg.Name) instalado com sucesso.")
        }
        catch {
            $this.Log.Error("Erro ao instalar $($pkg.Name): $_")
        }
    }
}

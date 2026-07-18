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
            $this.Log.Info("Offline installer found: $($pkg.OfflineFile)")
        }
        elseif ($pkg.DownloadUrl -and $this.HasInternet()) {
            $this.Download($pkg)
        }
        else {
            $this.Log.Error("$($pkg.Name): no offline installer and no internet. Skipping.")
            return
        }

        if ($pkg.IsArchive) {
            $this.ExtractArchive($pkg)
        }

        $this.Execute($pkg)
    }

    hidden [void] Download([PackageDefinition] $pkg) {
        $this.Log.Info("Downloading $($pkg.Name)...")
        $parentDir = Split-Path $pkg.OfflineFile -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $pkg.DownloadUrl -OutFile $pkg.OfflineFile -UseBasicParsing
            $this.Log.Success("Download complete: $($pkg.Name)")
        }
        catch {
            $this.Log.Error("Download failed for $($pkg.Name): $_")
            throw
        }
    }

    hidden [void] ExtractArchive([PackageDefinition] $pkg) {
        $targetDir = Split-Path $pkg.OfflineFile -Parent
        $this.Log.Info("Extracting $($pkg.OfflineFile)...")
        try {
            Expand-Archive -Path $pkg.OfflineFile -DestinationPath $targetDir -Force
            $this.Log.Success("Extraction complete: $($pkg.Name)")
        }
        catch {
            $this.Log.Warn("Extraction may have already been done or failed: $_")
        }
    }

    hidden [void] Execute([PackageDefinition] $pkg) {
        $installerPath = $pkg.InstallerPath
        if (-not (Test-Path $installerPath)) {
            $this.Log.Error("Installer not found: $installerPath")
            return
        }

        $ext = [System.IO.Path]::GetExtension($installerPath).ToLower()
        $this.Log.Info("Installing $($pkg.Name)...")

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
                    $this.Log.Error("Unsupported extension: $ext")
                    return
                }
            }
            $this.Log.Success("$($pkg.Name) installed successfully.")
        }
        catch {
            $this.Log.Error("Error installing $($pkg.Name): $_")
        }
    }
}

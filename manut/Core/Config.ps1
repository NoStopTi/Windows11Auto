class AppConfig {
    [string] $BasePath = "C:\manut"
    [string] $OfflinePath = "C:\manut\Auto\OFFLINE"
    [string] $ConfigPath = "C:\manut\Auto\CONFIGS"
    [string] $LogPath = "C:\manut\log"

    [string] OfflineFile([string] $fileName) {
        return Join-Path $this.OfflinePath $fileName
    }
}

class PackageDefinition {
    [string] $Name
    [string] $DownloadUrl
    [string] $OfflineFile
    [string] $InstallerPath
    [string] $SilentArgs
    [bool]   $WaitForExit = $true
    [bool]   $IsArchive = $false
    [string] $ArchiveInstallerRelPath = ""

    PackageDefinition(
        [string] $name,
        [string] $downloadUrl,
        [string] $offlineFile,
        [string] $silentArgs
    ) {
        $this.Name = $name
        $this.DownloadUrl = $downloadUrl
        $this.OfflineFile = $offlineFile
        $this.InstallerPath = $offlineFile
        $this.SilentArgs = $silentArgs
    }

    PackageDefinition(
        [string] $name,
        [string] $downloadUrl,
        [string] $offlineFile,
        [string] $silentArgs,
        [string] $archiveInstallerRelPath
    ) {
        $this.Name = $name
        $this.DownloadUrl = $downloadUrl
        $this.OfflineFile = $offlineFile
        $this.SilentArgs = $silentArgs
        $this.IsArchive = $true
        $this.ArchiveInstallerRelPath = $archiveInstallerRelPath
        $parentDir = Split-Path $offlineFile -Parent
        $this.InstallerPath = Join-Path $parentDir $archiveInstallerRelPath
    }
}

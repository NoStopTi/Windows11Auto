function Get-AnyDeskPackage {
    [OutputType([PackageDefinition])]
    param([AppConfig] $Config)

    return [PackageDefinition]::new(
        "AnyDesk",
        "https://download.anydesk.com/AnyDesk.exe",
        $Config.OfflineFile("AnyDesk.exe"),
        "--install C:\Progra~1\AnyDesk --start-with-win --create-desktop-icon"
    )
}

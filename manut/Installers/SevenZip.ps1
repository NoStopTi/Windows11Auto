function Get-SevenZipPackage {
    [OutputType([PackageDefinition])]
    param([AppConfig] $Config)

    return [PackageDefinition]::new(
        "7-Zip",
        "https://www.7-zip.org/a/7z2407-x64.exe",
        $Config.OfflineFile("7Z.exe"),
        "/S"
    )
}

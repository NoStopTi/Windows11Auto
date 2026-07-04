function Get-FirefoxPackage {
    [OutputType([PackageDefinition])]
    param([AppConfig] $Config)

    return [PackageDefinition]::new(
        "Mozilla Firefox",
        "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=pt-BR",
        $Config.OfflineFile("firefox.exe"),
        "/s"
    )
}

function Get-JavaPackage {
    [OutputType([PackageDefinition])]
    param([AppConfig] $Config)

    return [PackageDefinition]::new(
        "Java Runtime 64-bit",
        "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=250129_d8aa705069af427f9b83e66b34f5e380",
        $Config.OfflineFile("JAVA64.exe"),
        "/s /L c:\setup.log"
    )
}

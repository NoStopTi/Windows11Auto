function Get-AdobeReaderPackage {
    [OutputType([PackageDefinition])]
    param([AppConfig] $Config)

    return [PackageDefinition]::new(
        "Adobe Acrobat Reader DC",
        "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2400220759/AcroRdrDC2400220759_pt_BR.exe",
        $Config.OfflineFile("ADOBEACROBATREADER.exe"),
        "/sAll /rs"
    )
}

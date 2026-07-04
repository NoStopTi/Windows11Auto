function Get-GoogleChromePackage {
    [OutputType([PackageDefinition])]
    param([AppConfig] $Config)

    $pkg = [PackageDefinition]::new(
        "Google Chrome Enterprise",
        "https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7B1B8DE7EC-2005-766C-7814-3403244E61ED%7D%26lang%3Den%26browser%3D3%26usagestats%3D1%26appname%3DGoogle%2520Chrome%26needsadmin%3Dtrue%26ap%3Dx64-stable-statsdef_1%26brand%3DGCEB/dl/chrome/install/GoogleChromeEnterpriseBundle64.zip",
        $Config.OfflineFile("chrome.zip"),
        "",
        "Installers\GoogleChromeStandaloneEnterprise64.msi"
    )
    return $pkg
}

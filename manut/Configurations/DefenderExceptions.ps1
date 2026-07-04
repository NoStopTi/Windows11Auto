function Set-DefenderExceptions {
    param([Logger] $Log)

    $exclusions = @(
        "c:\manut",
        "c:\windows\KMS-QADhook.dll",
        "c:\windows\KMS-R@1nhook.exe",
        "C:\manut\Auto\Ativador\W10\AW10.exe",
        "c:\windows\KMS-R@1n.exe"
    )

    $Log.Info("Configurando excecoes do Windows Defender...")
    foreach ($path in $exclusions) {
        Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
    }
    $Log.Success("Excecoes do Defender configuradas.")
}

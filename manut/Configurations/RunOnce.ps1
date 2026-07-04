function Register-FinishingScript {
    param(
        [Logger]    $Log,
        [AppConfig] $Config
    )

    $name  = "Call-Finishing"
    $value = "cmd /c start powershell $($Config.BasePath)\Configurations\finishing.ps1"
    $path  = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"

    $Log.Info("Registrando script de finalizacao no RunOnce...")
    $existing = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
    if ($existing) {
        Set-ItemProperty -Path $path -Name $name -Value $value
    }
    else {
        New-ItemProperty -Path $path -Name $name -Value $value | Out-Null
    }
    $Log.Success("Script de finalizacao registrado.")
}

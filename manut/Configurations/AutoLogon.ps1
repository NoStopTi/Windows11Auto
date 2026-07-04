function Enable-AutoLogon {
    param(
        [Logger] $Log,
        [string] $Username = "administrador",
        [string] $Password = "1234"
    )

    $Log.Info("Configurando Auto Logon para '$Username'...")
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "1"
    Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $Username
    Set-ItemProperty -Path $regPath -Name "DefaultDomainName" -Value $env:COMPUTERNAME

    $existingPwd = Get-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
    if ($existingPwd) {
        Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $Password
    } else {
        New-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $Password -PropertyType String -Force | Out-Null
    }

    $Log.Success("Auto Logon configurado para '$Username'.")
}

function Disable-AutoLogon {
    param([Logger] $Log)

    $Log.Info("Desativando Auto Logon...")
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "0"
    Remove-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue

    $Log.Success("Auto Logon desativado.")
}

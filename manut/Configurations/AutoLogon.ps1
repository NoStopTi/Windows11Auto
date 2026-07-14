if (-not (Get-Command Import-EnvSecrets -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\PostFormatSetup.ps1"
}

function ConvertFrom-SecureStringToPlainText {
    param([Parameter(Mandatory)] [System.Security.SecureString] $SecureString)

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Enable-AutoLogon {
    param(
        [Logger] $Log,
        [string] $Username = ".\ADM01",
        [string] $EnvFilePath = "C:\manut\Core\secure\.env"
    )

    $Log.Info("Configurando Auto Logon para '$Username'...")

    try {
        $secrets = Import-EnvSecrets -Path $EnvFilePath -RequiredKeys @("ADM01_PASSWORD")
    }
    catch {
        $Log.Error("Falha ao carregar segredos: $_")
        return
    }
    $Password = ConvertFrom-SecureStringToPlainText -SecureString $secrets["ADM01_PASSWORD"]

    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "1"
    Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $Username
    #Set-ItemProperty -Path $regPath -Name "DefaultDomainName" -Value $env:COMPUTERNAME

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

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

function Write-AutoLogonMessage {
    param([Logger] $Log, [string] $Level, [string] $Message)

    if (-not $Log) {
        Write-Host $Message
        return
    }

    switch ($Level) {
        "Success" { $Log.Success($Message) }
        "Warn"    { $Log.Warn($Message) }
        "Error"   { $Log.Error($Message) }
        default   { $Log.Info($Message) }
    }
}

function Enable-AutoLogon {
    param(
        [Logger] $Log,
        [string] $Username = "ADM01",
        [string] $EnvFilePath = "C:\manut\Core\secure\.env"
    )

    Write-AutoLogonMessage -Log $Log -Level "Info" -Message "Enabling persistent autologon for '$Username'..."

    try {
        $secrets = Import-EnvSecrets -Path $EnvFilePath -RequiredKeys @("ADM01_PASSWORD")
    }
    catch {
        Write-AutoLogonMessage -Log $Log -Level "Error" -Message "Autologon NOT enabled - failed to load secrets: $_"
        return
    }

    # Align the account password with the one written to Winlogon, otherwise the
    # autologon fails whenever .env differs from the password set by autounattend.xml
    $account = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
    if ($account) {
        Set-LocalUser -Name $Username -Password $secrets["ADM01_PASSWORD"] -PasswordNeverExpires $true
    }
    else {
        Write-AutoLogonMessage -Log $Log -Level "Warn" -Message "Account '$Username' not found; autologon may fail."
    }

    $Password = ConvertFrom-SecureStringToPlainText -SecureString $secrets["ADM01_PASSWORD"]

    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "1" -Type String
    Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $Username -Type String
    Set-ItemProperty -Path $regPath -Name "DefaultDomainName" -Value $env:COMPUTERNAME -Type String
    Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $Password -Type String

    # autounattend.xml <LogonCount> leaves AutoLogonCount behind; once it reaches 0
    # Winlogon wipes the autologon on the next boot. Remove it so autologon persists
    # until Disable-AutoLogon runs in the last step (finishing.ps1).
    Remove-ItemProperty -Path $regPath -Name "AutoLogonCount" -ErrorAction SilentlyContinue

    Write-AutoLogonMessage -Log $Log -Level "Success" -Message "Autologon enabled for '$Username' until the finishing step."
}

function Disable-AutoLogon {
    param([Logger] $Log)

    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "0" -Type String
    Remove-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $regPath -Name "AutoLogonCount" -ErrorAction SilentlyContinue

    Write-AutoLogonMessage -Log $Log -Level "Success" -Message "Autologon disabled."
}

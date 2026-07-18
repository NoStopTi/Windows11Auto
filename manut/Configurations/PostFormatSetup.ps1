if (-not ('Logger' -as [type])) {
    . "$PSScriptRoot\..\Core\Logger.ps1"
}

function Import-EnvSecrets {
    param(
        [Parameter(Mandatory)]
        [string] $Path,
        [Parameter(Mandatory)]
        [string[]] $RequiredKeys
    )

    if (-not (Test-Path $Path)) {
        throw "Secrets file not found: $Path"
    }

    $secrets = @{}
    Get-Content -Path $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        if ($line -match "^([^=]+)=(.*)$") {
            $secrets[$Matches[1].Trim()] = ConvertTo-SecureString $Matches[2] -AsPlainText -Force
        }
    }

    foreach ($key in $RequiredKeys) {
        if (-not $secrets.ContainsKey($key)) {
            throw "Required key missing from secrets file: $key"
        }
    }

    return $secrets
}
function Set-AdministratorPasswords {
    param(
        [Logger]    $Log,
        [hashtable] $Secrets
    )

    $adm01 = Get-LocalUser -Name "adm01" -ErrorAction SilentlyContinue
    if ($adm01) {
        $Log.Info("Updating password for account 'adm01'...")
        Set-LocalUser -Name "adm01" -Password $Secrets["ADM01_PASSWORD"]
        $Log.Success("Password for 'adm01' updated.")
    }
    else {
        $Log.Warn("Account 'adm01' not found. Skipping.")
    }

    foreach ($name in @("Administrator", "Administrador")) {
        $account = Get-LocalUser -Name $name -ErrorAction SilentlyContinue
        if ($account) {
            $Log.Info("Updating password for account '$name'...")
            Set-LocalUser -Name $name -Password $Secrets["ADMIN_PASSWORD"]
            $Log.Success("Password for '$name' updated.")
        }
    }
}
function New-StandardWorkstationUser {
    param(
        [Logger]    $Log,
        [hashtable] $Secrets,
        [string]    $UserName = "User",
        [string]    $FullName = "Simple User",
        [string]    $Group = "Users"
    )

    $existing = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
    if ($existing) {
        $Log.Warn("User '$UserName' already exists. Skipping creation.")
        return
    }

    $Log.Info("Creating standard user '$UserName'...")
    New-LocalUser -Name $UserName -Password $Secrets["STANDARD_USER_PASSWORD"] `
        -FullName $FullName -Description "Standard limited user" | Out-Null
    Add-LocalGroupMember -Group $Group -Member $UserName
    $Log.Success("User '$UserName' created and added to group '$Group'.")
}
function Get-MotherboardComputerName {
    param(
        [string] $Prefix = "MAQ"
    )  

    $serial = (Get-CimInstance -Class Win32_ComputerSystemProduct).UUID

    if ([string]::IsNullOrWhiteSpace($serial) -or $serial -match "O\.?E\.?M\.?|None|Default string") {
        $Log.Warn("Motherboard serial number is invalid or not provided by the manufacturer.")
        return $null
    }

    $cleanSerial = ($serial -replace '[^A-Za-z0-9]', '').ToUpper()

    if ($cleanSerial.Length -lt 8) {
        $Log.Warn("Motherboard serial number has fewer than 8 usable characters: '$cleanSerial'.")
        return $null
    }

    $shortId = $cleanSerial.Substring(0, 8)
    $computerName = "$Prefix-$shortId"

    return $computerName
}
function Set-MotherboardBasedComputerName {
    param(
        [Logger] $Log
    )

    $computerName = Get-MotherboardComputerName -Log $Log
    if (-not $computerName) {
        $Log.Warn("Computer rename skipped: could not generate a valid name.")
        return
    }

    if ($env:COMPUTERNAME -eq $computerName) {
        $Log.Info("Computer is already named '$computerName'. No action needed.")
        return
    }

    $Log.Info("Renaming computer to '$computerName'...")
    Rename-Computer -NewName $computerName -Force
    $Log.Success("Computer renamed to '$computerName'. Restart to apply.")
}
function Complete-PostFormatSetup {
    param(
        [Logger] $Log,
        [string] $EnvFilePath = "C:\manut\Core\secure\.env"
    )

    $requiredKeys = @("ADM01_PASSWORD", "ADMIN_PASSWORD", "STANDARD_USER_PASSWORD")

    $Log.Info("Loading secrets from '$EnvFilePath'...")
    try {
        $secrets = Import-EnvSecrets -Path $EnvFilePath -RequiredKeys $requiredKeys
    }
    catch {
        $Log.Error("Failed to load secrets: $_")
        return
    }

    Set-AdministratorPasswords -Log $Log -Secrets $secrets
    New-StandardWorkstationUser -Log $Log -Secrets $secrets
    Set-MotherboardBasedComputerName -Log $Log
    Disable-AutoLogon -Log $Log

    $Log.Success("Credential provisioning complete.")
}

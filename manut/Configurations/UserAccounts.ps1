if (-not (Get-Command Import-EnvSecrets -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\PostFormatSetup.ps1"
}

function Enable-LocalAdminAccount {
    param(
        [Logger] $Log,
        [string] $EnvFilePath = "C:\manut\Core\secure\.env"
    )

    $Log.Info("Enabling local administrator account...")

    try {
        $secrets = Import-EnvSecrets -Path $EnvFilePath -RequiredKeys @("ADMIN_PASSWORD")
    }
    catch {
        $Log.Error("Failed to load secrets: $_")
        return
    }
    $newPwd = $secrets["ADMIN_PASSWORD"]

    $user = Get-LocalUser -Name "administrador" -ErrorAction SilentlyContinue
    if ($user) {
        Set-LocalUser -Name "administrador" -Password $newPwd
        Enable-LocalUser -Name "administrador"
        $Log.Success("'administrador' account enabled.")
        return
    }

    $user = Get-LocalUser -Name "administrator" -ErrorAction SilentlyContinue
    if ($user) {
        Set-LocalUser -Name "administrator" -Password $newPwd
        Enable-LocalUser -Name "administrator"
        $Log.Success("'administrator' account enabled.")
        return
    }

    $Log.Warn("Local administrator account not found.")
}

function Set-UserPasswordNeverExpires {
    param(
        [Logger] $Log,
        [string] $Username = "user"
    )

    $Log.Info("Setting password to never expire for '$Username'...")
    Set-LocalUser -Name $Username -PasswordNeverExpires $true -ErrorAction SilentlyContinue
    $Log.Success("Password for user '$Username' set to never expire.")
}

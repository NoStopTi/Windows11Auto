if (-not (Get-Command Import-EnvSecrets -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\PostFormatSetup.ps1"
}

function Enable-LocalAdminAccount {
    param(
        [Logger] $Log,
        [string] $EnvFilePath = "C:\manut\Core\secure\.env"
    )

    $Log.Info("Ativando conta de administrador local...")

    try {
        $secrets = Import-EnvSecrets -Path $EnvFilePath -RequiredKeys @("ADMIN_PASSWORD")
    }
    catch {
        $Log.Error("Falha ao carregar segredos: $_")
        return
    }
    $newPwd = $secrets["ADMIN_PASSWORD"]

    $user = Get-LocalUser -Name "administrador" -ErrorAction SilentlyContinue
    if ($user) {
        Set-LocalUser -Name "administrador" -Password $newPwd
        Enable-LocalUser -Name "administrador"
        $Log.Success("Conta 'administrador' ativada.")
        return
    }

    $user = Get-LocalUser -Name "administrator" -ErrorAction SilentlyContinue
    if ($user) {
        Set-LocalUser -Name "administrator" -Password $newPwd
        Enable-LocalUser -Name "administrator"
        $Log.Success("Conta 'administrator' ativada.")
        return
    }

    $Log.Warn("Conta de administrador local nao encontrada.")
}

function Set-UserPasswordNeverExpires {
    param(
        [Logger] $Log,
        [string] $Username = "user"
    )

    $Log.Info("Configurando senha sem expiracao para '$Username'...")
    Set-LocalUser -Name $Username -PasswordNeverExpires $true -ErrorAction SilentlyContinue
    $Log.Success("Senha do usuario '$Username' configurada para nunca expirar.")
}

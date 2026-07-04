function Import-EnvSecrets {
    param(
        [Parameter(Mandatory)]
        [string] $Path,
        [Parameter(Mandatory)]
        [string[]] $RequiredKeys
    )

    if (-not (Test-Path $Path)) {
        throw "Arquivo de segredos nao encontrado: $Path"
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
            throw "Chave obrigatoria ausente no arquivo de segredos: $key"
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
        $Log.Info("Atualizando senha da conta 'adm01'...")
        Set-LocalUser -Name "adm01" -Password $Secrets["ADM01_PASSWORD"]
        $Log.Success("Senha de 'adm01' atualizada.")
    }
    else {
        $Log.Warn("Conta 'adm01' nao encontrada. Pulando.")
    }

    foreach ($name in @("Administrator", "Administrador")) {
        $account = Get-LocalUser -Name $name -ErrorAction SilentlyContinue
        if ($account) {
            $Log.Info("Atualizando senha da conta '$name'...")
            Set-LocalUser -Name $name -Password $Secrets["ADMIN_PASSWORD"]
            $Log.Success("Senha de '$name' atualizada.")
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
        $Log.Warn("Usuario '$UserName' ja existe. Pulando criacao.")
        return
    }

    $Log.Info("Criando usuario padrao '$UserName'...")
    New-LocalUser -Name $UserName -Password $Secrets["STANDARD_USER_PASSWORD"] `
        -FullName $FullName -Description "Standard limited user" | Out-Null
    Add-LocalGroupMember -Group $Group -Member $UserName
    $Log.Success("Usuario '$UserName' criado e adicionado ao grupo '$Group'.")
}

function Get-MotherboardComputerName {
    param(
        [Logger] $Log,
        [string] $Prefix = "MAQ"
    )

    $baseBoard = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction SilentlyContinue
    $serial = $baseBoard.SerialNumber

    if ([string]::IsNullOrWhiteSpace($serial) -or $serial -match "O\.?E\.?M\.?|None|Default string") {
        $Log.Warn("Numero de serie da placa-mae invalido ou nao informado pelo fabricante.")
        return $null
    }

    $cleanSerial = ($serial -replace '[^A-Za-z0-9]', '').ToUpper()

    if ($cleanSerial.Length -lt 8) {
        $Log.Warn("Numero de serie da placa-mae tem menos de 8 caracteres uteis: '$cleanSerial'.")
        return $null
    }

    $shortId = $cleanSerial.Substring(0, 8)
    $computerName = "$Prefix-$shortId"

    $Log.Info("Nome de computador gerado a partir da placa-mae: $computerName")
    return $computerName
}

function Set-MotherboardBasedComputerName {
    param(
        [Logger] $Log
    )

    $computerName = Get-MotherboardComputerName -Log $Log
    if (-not $computerName) {
        $Log.Warn("Renomeacao de computador pulada: nao foi possivel gerar um nome valido.")
        return
    }

    if ($env:COMPUTERNAME -eq $computerName) {
        $Log.Info("Computador ja esta nomeado como '$computerName'. Nenhuma acao necessaria.")
        return
    }

    $Log.Info("Renomeando computador para '$computerName'...")
    Rename-Computer -NewName $computerName -Force
    $Log.Success("Computador renomeado para '$computerName'. Reinicie para aplicar.")
}

function Complete-PostFormatSetup {
    param(
        [Logger] $Log,
        [string] $EnvFilePath = "C:\manut\Core\secure\.env"
    )

    $requiredKeys = @("ADM01_PASSWORD", "ADMIN_PASSWORD", "STANDARD_USER_PASSWORD")

    $Log.Info("Carregando segredos de '$EnvFilePath'...")
    try {
        $secrets = Import-EnvSecrets -Path $EnvFilePath -RequiredKeys $requiredKeys
    }
    catch {
        $Log.Error("Falha ao carregar segredos: $_")
        return
    }

    Set-AdministratorPasswords -Log $Log -Secrets $secrets
    New-StandardWorkstationUser -Log $Log -Secrets $secrets
    Set-MotherboardBasedComputerName -Log $Log

    $Log.Success("Provisionamento de credenciais concluido.")
}

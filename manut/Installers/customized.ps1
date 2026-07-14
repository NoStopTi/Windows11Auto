function Install-CustomizedAppsForMachine {
    param(
        [Logger] $Log,
        [string] $BasePath
    )

    $machinesJsonPath = Join-Path $BasePath "Installers\machines.json"

    if (-not (Test-Path $machinesJsonPath)) {
        $Log.Warn("Arquivo machines.json nao encontrado em '$machinesJsonPath'.")
        return
    }

    $machineUuid = (Get-CimInstance -ClassName Win32_ComputerSystemProduct).UUID
    $machinesConfig = Get-Content -Path $machinesJsonPath -Raw | ConvertFrom-Json

    $matchedMachine = $null
    foreach ($company in $machinesConfig.companies) {
        foreach ($machine in $company.machines) {
            if ($machine.uuid -eq $machineUuid) {
                $matchedMachine = $machine
                break
            }
        }
        if ($matchedMachine) { break }
    }

    if (-not $matchedMachine) {
        $Log.Info("Nenhuma configuracao personalizada encontrada para esta maquina (UUID: $machineUuid).")
        return
    }

    $Log.Info("Maquina reconhecida (UUID: $machineUuid). Executando instalacoes personalizadas...")
    foreach ($app in $matchedMachine.apps) {
        $appScriptPath = Join-Path $BasePath ($app.path -replace '^\.[\\/]', '')
        if (Test-Path $appScriptPath) {
            $Log.Info("Instalando '$($app.appName)'...")
            $appProcess = Start-Process -FilePath "powershell.exe" `
                -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$appScriptPath`"") `
                -Wait -PassThru
            if ($appProcess.ExitCode -eq 0) {
                $Log.Success("'$($app.appName)' instalado com sucesso.")
            }
            else {
                $Log.Warn("'$($app.appName)' retornou codigo de saida $($appProcess.ExitCode).")
            }
        }
        else {
            $Log.Warn("Script nao encontrado para '$($app.appName)': $appScriptPath")
        }
    }
}

function Install-CustomizedAppsForMachine {
    param(
        [Logger] $Log,
        [string] $BasePath
    )

    $machinesJsonPath = Join-Path $BasePath "Installers\machines.json"

    if (-not (Test-Path $machinesJsonPath)) {
        $Log.Warn("machines.json file not found at '$machinesJsonPath'.")
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
        $Log.Info("No custom configuration found for this machine (UUID: $machineUuid).")
        return
    }

    $Log.Info("Machine recognized (UUID: $machineUuid). Running custom installations...")
   
    foreach ($app in $matchedMachine.apps) {
        $appScriptPath = Join-Path $BasePath ($app.path -replace '^\.[\\/]', '')
        if (Test-Path $appScriptPath) {
            $Log.Info("Installing '$($app.appName)'...")
            $appProcess = Start-Process -FilePath "powershell.exe" `
                -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$appScriptPath`"") `
                -Wait -PassThru
            if ($appProcess.ExitCode -eq 0) {
                $Log.Success("'$($app.appName)' installed successfully.")
            }
            else {
                $Log.Warn("'$($app.appName)' returned exit code $($appProcess.ExitCode).")
            }
        }
        else {
            $Log.Warn("Script not found for '$($app.appName)': $appScriptPath")
        }
    }

     foreach ($conf in $matchedMachine.configs) {
        $configScriptPath = Join-Path $BasePath ($conf.path -replace '^\.[\\/]', '')
        
        if (Test-Path $configScriptPath) {
          $confProcess = Start-Process -FilePath "powershell.exe" `
                -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$configScriptPath`"") `
                -Wait -PassThru
            if ($confProcess.ExitCode -eq 0) {
                $Log.Success("'$($conf.confName)' Configured successfully.")
            }
            else {
                $Log.Warn("'$($conf.confName)' returned exit code $($confProcess.ExitCode).")
            }
        }
        else {
            $Log.Warn("Script not found for '$($config.confName)': $configScriptPath")
        }
    }
}

function Set-WorkstationTaskbar {
    param(
        [Logger]    $Log,
        [AppConfig] $Config
    )

    $regFile  = Join-Path $Config.ConfigPath "barraDeTarefas\workStation\taskBand.reg"
    $lnkDir   = Join-Path $Config.ConfigPath "barraDeTarefas\workStation\TaskBar"
    $targetDir = "$env:USERPROFILE\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"

    $Log.Info("Configuring taskbar...")

    if (Test-Path $regFile) {
        regedit /s $regFile
    }

    if (Test-Path $lnkDir) {
        Copy-Item -Path "$lnkDir\*.*" -Destination $targetDir -Force -ErrorAction SilentlyContinue
    }

    $Log.Success("Taskbar configured.")
}

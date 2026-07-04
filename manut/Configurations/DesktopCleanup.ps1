function Clear-DesktopShortcuts {
    param([Logger] $Log)

    $Log.Info("Limpando atalhos da area de trabalho...")
    Remove-Item "$env:PUBLIC\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:USERPROFILE\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
    $Log.Success("Area de trabalho limpa.")
}

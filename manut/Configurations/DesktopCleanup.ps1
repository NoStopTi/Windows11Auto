function Clear-DesktopShortcuts {
    param([Logger] $Log)

    $Log.Info("Cleaning up desktop shortcuts...")
    Remove-Item "$env:PUBLIC\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:USERPROFILE\Desktop\*.lnk" -Force -ErrorAction SilentlyContinue
    $Log.Success("Desktop cleaned up.")
}

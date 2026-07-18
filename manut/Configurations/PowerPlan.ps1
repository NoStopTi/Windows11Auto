function Set-HighPerformancePlan {
    param([Logger] $Log)

    $Log.Info("Setting power plan: High Performance...")
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    $Log.Success("Power plan configured.")
}

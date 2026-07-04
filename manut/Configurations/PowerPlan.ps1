function Set-HighPerformancePlan {
    param([Logger] $Log)

    $Log.Info("Definindo plano de energia: Alto Desempenho...")
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    $Log.Success("Plano de energia configurado.")
}

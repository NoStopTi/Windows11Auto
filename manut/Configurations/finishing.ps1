#Requires -RunAsAdministrator
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force -ErrorAction SilentlyContinue

$basePath ="C:\manut"

# --- Carregar Core ---
. "$basePath\Core\Logger.ps1"
. "$basePath\Core\Config.ps1"

# --- Carregar Configuracoes ---
. "$basePath\Configurations\AutoLogon.ps1"
. "$basePath\Configurations\PostFormatSetup.ps1"
 
Clear-Host

# --- Inicializar ---
$config = [AppConfig]::new()
$logger = [Logger]::new($config.LogPath)
$osCaption = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption

$logger.Info("============================================")
$logger.Info("  SCRIPT DE FINALIZACAO POS-FORMATACAO")
$logger.Info("  OS: $osCaption")
$logger.Info("============================================")

if ($osCaption -match "Windows 1[01] (Pro|Home)") {
    Complete-PostFormatSetup -Log $logger
}
else {
    $logger.Warn("Sistema operacional nao suportado pelo script de finalizacao: $osCaption")
}

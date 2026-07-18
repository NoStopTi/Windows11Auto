#Requires -RunAsAdministrator
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force -ErrorAction SilentlyContinue

$basePath ="C:\manut"

# --- Load Core ---
. "$basePath\Core\Logger.ps1"
. "$basePath\Core\Config.ps1"

# --- Load Configurations ---
. "$basePath\Configurations\AutoLogon.ps1"
. "$basePath\Configurations\PostFormatSetup.ps1"

Clear-Host

# --- Initialize ---
$config = [AppConfig]::new()
$logger = [Logger]::new($config.LogPath)
$osCaption = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption

$logger.Info("============================================")
$logger.Info("  POST-FORMAT FINISHING SCRIPT")
$logger.Info("  OS: $osCaption")
$logger.Info("============================================")

if ($osCaption -match "Windows 1[01] (Pro|Home)") {
    Complete-PostFormatSetup -Log $logger
}
else {
    $logger.Warn("Operating system not supported by the finishing script: $osCaption")
}

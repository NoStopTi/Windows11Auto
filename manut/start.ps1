# --- Bootstrap: localizar pendrive e copiar base ---
$basePath = "C:\manut"


. "$basePath\Core\Logger.ps1"
. "$basePath\Core\Config.ps1"
. "$basePath\Core\PackageInstaller.ps1"

# --- Carregar Configuracoes ---
. "$basePath\Configurations\DefenderExceptions.ps1"
. "$basePath\Configurations\NetworkProtocols.ps1"
. "$basePath\Configurations\PowerPlan.ps1"
. "$basePath\Configurations\UserAccounts.ps1"
. "$basePath\Configurations\Taskbar.ps1"
. "$basePath\Configurations\DesktopCleanup.ps1"
. "$basePath\Configurations\WindowsActivation.ps1"
. "$basePath\Configurations\WindowsTweaks.ps1"
. "$basePath\Configurations\RunOnce.ps1"
. "$basePath\Configurations\AutoLogon.ps1"

Enable-AutoLogon


# --- Carregar Definicoes de Pacotes ---
. "$basePath\Installers\Firefox.ps1"
. "$basePath\Installers\Java.ps1"
. "$basePath\Installers\AdobeReader.ps1"
. "$basePath\Installers\SevenZip.ps1"
. "$basePath\Installers\AnyDesk.ps1"
. "$basePath\Installers\GoogleChrome.ps1"
. "$basePath\Installers\Office2021.ps1"
. "$basePath\Installers\customized.ps1"

# --- Inicializar ---
$config = [AppConfig]::new()
$logger = [Logger]::new($config.LogPath)
$installer = [PackageInstaller]::new($logger, $config)

$logger.Info("============================================")
$logger.Info("  INICIO DA INSTALACAO E CONFIGURACAO")
$logger.Info("  OS: $((Get-CimInstance Win32_OperatingSystem).Caption)")
$logger.Info("  Data: $(Get-Date -Format 'dd/MM/yyyy HH:mm')")
$logger.Info("============================================")

# --- Fase 1: Seguranca e Rede ---
Set-DefenderExceptions -Log $logger
Disable-UnusedProtocols -Log $logger
Set-HighPerformancePlan -Log $logger

# --- Fase 2: Instalar Programas ---
$packages = @(
    (Get-FirefoxPackage       -Config $config),
    (Get-JavaPackage          -Config $config),
    (Get-AdobeReaderPackage   -Config $config),
    (Get-SevenZipPackage      -Config $config),
    (Get-AnyDeskPackage       -Config $config),
    (Get-GoogleChromePackage  -Config $config)
)

foreach ($pkg in $packages) {
    $installer.Install($pkg)
}

Install-Office2021 -Log $logger -Config $config

# --- Fase 2.5: Instalacoes Personalizadas por Maquina (UUID) ---
Install-CustomizedAppsForMachine -Log $logger -BasePath $basePath

# --- Fase 3: Configuracoes do Sistema ---
$osCaption = (Get-CimInstance Win32_OperatingSystem).Caption

if ($osCaption -match "Windows 10") {
    Set-Windows10Tweaks -Log $logger
}
elseif ($osCaption -match "Windows 11") {
    Set-Windows11Tweaks -Log $logger
}

# --- Fase 4: Configuracoes Finais (Workstation) ---
if ($osCaption -match "Windows 1[01] (Pro|Home)") {
    Register-FinishingScript       -Log $logger -Config $config
    Set-WorkstationTaskbar         -Log $logger -Config $config
    Enable-LocalAdminAccount       -Log $logger
    Enable-AutoLogon               -Log $logger
    Clear-DesktopShortcuts         -Log $logger
    Set-UserPasswordNeverExpires   -Log $logger -Username "user"
    Start-WindowsAndOfficeActivation -Log $logger -Config $config
}

$logger.Info("============================================")
$logger.Success("  PROCESSO CONCLUIDO!")
$logger.Info("  Log salvo em: $($logger.LogPath)")
$logger.Info("============================================")

# --- Bootstrap: locate pendrive and copy base files ---
$basePath = "C:\manut"


. "$basePath\Core\Logger.ps1"
. "$basePath\Core\Config.ps1"
. "$basePath\Core\PackageInstaller.ps1"
. "$basePath\Core\OfflineSync.ps1"

# --- Load Configurations ---
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


# --- Load Package Definitions ---
. "$basePath\Installers\Firefox.ps1"
. "$basePath\Installers\Java.ps1"
. "$basePath\Installers\AdobeReader.ps1"
. "$basePath\Installers\SevenZip.ps1"
. "$basePath\Installers\AnyDesk.ps1"
. "$basePath\Installers\GoogleChrome.ps1"
. "$basePath\Installers\Office2021.ps1"
. "$basePath\Installers\customized.ps1"

# --- Initialize ---
$config = [AppConfig]::new()
$logger = [Logger]::new($config.LogPath)
$installer = [PackageInstaller]::new($logger, $config)

$logger.Info("============================================")
$logger.Info("  STARTING INSTALLATION AND CONFIGURATION")
$logger.Info("  OS: $((Get-CimInstance Win32_OperatingSystem).Caption)")
$logger.Info("  Date: $(Get-Date -Format 'dd/MM/yyyy HH:mm')")
$logger.Info("============================================")

# --- Phase 1: Security and Network ---
Set-DefenderExceptions -Log $logger
Disable-UnusedProtocols -Log $logger
Set-HighPerformancePlan -Log $logger

$packages = @(
    (Get-FirefoxPackage       -Config $config),
    (Get-JavaPackage          -Config $config),
    (Get-AdobeReaderPackage   -Config $config),
    (Get-SevenZipPackage      -Config $config),
    (Get-AnyDeskPackage       -Config $config),
    (Get-GoogleChromePackage  -Config $config)
)

# --- Fase 1.5: Update offline installers older than 30 days (local + pendrive) ---
Sync-OfflineInstallers -Log $logger -Config $config -Packages $packages -MaxAgeDays 30

# --- Fase 2: Install Programs ---
foreach ($pkg in $packages) {
    $installer.Install($pkg)
}

Install-Office2021 -Log $logger -Config $config

# --- Phase 2.5: Custom Installations per Machine (UUID) ---
Install-CustomizedAppsForMachine -Log $logger -BasePath $basePath

# --- Phase 3: System Configurations ---
$osCaption = (Get-CimInstance Win32_OperatingSystem).Caption

if ($osCaption -match "Windows 10") {
    Set-Windows10Tweaks -Log $logger
}
elseif ($osCaption -match "Windows 11") {
    Set-Windows11Tweaks -Log $logger
}

# --- Phase 4: Final Configurations (Workstation) ---
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
$logger.Success("  PROCESS COMPLETE!")
$logger.Info("  Log saved to: $($logger.LogPath)")
$logger.Info("============================================")

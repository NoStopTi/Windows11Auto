# Configura o Wi-Fi logo apos a formatacao e aguarda acesso a internet.
# Rede e senha vem de C:\manut\Core\secure\.env (WIFI_SSID, WIFI_PASSWORD, WIFI_AUTH);
# o perfil e montado a partir do modelo wifi-default.xml.
# Uso: powershell.exe -ExecutionPolicy Bypass -File C:\manut\Configurations\connect-wifi.ps1
param(
    [string] $EnvFilePath = "C:\manut\Core\secure\.env",
    [string] $TemplateFile = "$PSScriptRoot\wifi-default.xml",
    [string] $DriversPath = "C:\manut\Drivers\WiFi",
    [int] $TimeoutSeconds = 300
)

. "$PSScriptRoot\AutoLogon.ps1"

$log = "C:\manut\connect-wifi.log"
function Write-Log($msg) {
    $line = "{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $msg
    Write-Host $line
    Add-Content -Path $log -Value $line -ErrorAction SilentlyContinue
}

function Test-Internet {
    try {
        $r = Invoke-WebRequest -Uri "http://www.msftconnecttest.com/connecttest.txt" -UseBasicParsing -TimeoutSec 5
        return $r.Content -eq "Microsoft Connect Test"
    }
    catch { return $false }
}

function Test-WlanAdapter {
    return [bool](netsh wlan show interfaces | Select-String -Pattern "GUID")
}

if (Test-Internet) {
    Write-Log "Internet ja disponivel."
    exit 0
}

try {
    $secrets = Import-EnvSecrets -Path $EnvFilePath -RequiredKeys @("WIFI_SSID", "WIFI_PASSWORD")
}
catch {
    Write-Log "Falha ao carregar segredos: $_"
    exit 1
}
$ssid = ConvertFrom-SecureStringToPlainText -SecureString $secrets["WIFI_SSID"]
$auth = "WPA2PSK"
if ($secrets.ContainsKey("WIFI_AUTH")) {
    $auth = ConvertFrom-SecureStringToPlainText -SecureString $secrets["WIFI_AUTH"]
}

# Garante o servico de Wi-Fi ligado
Set-Service -Name WlanSvc -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service -Name WlanSvc -ErrorAction SilentlyContinue

# Notebooks novos podem nao ter driver de Wi-Fi nativo no Windows:
# instala os drivers colocados em C:\manut\Drivers\WiFi (arquivos .inf)
if (-not (Test-WlanAdapter) -and (Test-Path $DriversPath)) {
    Write-Log "Adaptador Wi-Fi nao encontrado. Instalando drivers de '$DriversPath'..."
    Write-Log ((pnputil.exe /add-driver "$DriversPath\*.inf" /subdirs /install) -join " ")
}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while (-not (Test-WlanAdapter) -and (Get-Date) -lt $deadline) {
    Write-Log "Aguardando adaptador Wi-Fi..."
    Start-Sleep -Seconds 5
}
if (-not (Test-WlanAdapter)) {
    Write-Log "Falha: nenhum adaptador Wi-Fi encontrado. Coloque o driver em '$DriversPath'."
    exit 1
}

# Monta o perfil a partir do modelo; o arquivo com a senha existe so durante a importacao
$profileFile = Join-Path $env:TEMP "wifi-profile.xml"
$xml = (Get-Content -Path $TemplateFile -Raw).
    Replace("{{WIFI_SSID}}", [Security.SecurityElement]::Escape($ssid)).
    Replace("{{WIFI_AUTH}}", $auth).
    Replace("{{WIFI_PASSWORD}}", [Security.SecurityElement]::Escape((ConvertFrom-SecureStringToPlainText -SecureString $secrets["WIFI_PASSWORD"])))
[IO.File]::WriteAllText($profileFile, $xml, (New-Object Text.UTF8Encoding $false))
try {
    Write-Log ((netsh wlan add profile filename="$profileFile" user=all) -join " ")
}
finally {
    Remove-Item -LiteralPath $profileFile -Force -ErrorAction SilentlyContinue
}

while ((Get-Date) -lt $deadline) {
    Write-Log ((netsh wlan connect name="$ssid") -join " ")
    Start-Sleep -Seconds 10
    if (Test-Internet) {
        Write-Log "Conectado a '$ssid' com acesso a internet."
        exit 0
    }
}

Write-Log "Falha: sem internet apos $TimeoutSeconds segundos."
netsh wlan show interfaces | Out-File -Append $log
exit 1

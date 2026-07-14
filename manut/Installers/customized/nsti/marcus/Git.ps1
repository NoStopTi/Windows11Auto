
<#
.SYNOPSIS
    Baixa e instala o Git for Windows (64-bit) de forma 100% silenciosa.
 
.DESCRIPTION
    Consulta a API do GitHub para obter a versao mais recente do Git for
    Windows, baixa o instalador oficial e executa a instalacao silenciosa
    (sem janelas, sem cliques). Informa cada etapa no console.
 
.NOTES
    Execute em um PowerShell com privilegios de Administrador para que a
    instalacao (que grava em Program Files e no registro) funcione sem erros.
#>
 
[CmdletBinding()]
param(
    # Pasta temporaria onde o instalador sera baixado
    [string]$DownloadFolder = "$env:TEMP\GitInstall"
)
 
$ErrorActionPreference = "Stop"
 
function Write-Step {
    param([string]$Message)
    Write-Host ">> $Message" -ForegroundColor Cyan
}
 
try {
    # 1. Verifica se ja existe uma instalacao do Git
    Write-Step "Verificando se o Git ja esta instalado..."
    $existingGit = Get-Command git -ErrorAction SilentlyContinue
    if ($existingGit) {
        $version = & git --version
        Write-Host "Git ja esta instalado: $version" -ForegroundColor Yellow
        Write-Host "Encerrando sem reinstalar. Use -Force removendo esta verificacao se quiser reinstalar." -ForegroundColor Yellow
        return
    }
 
    # 2. Prepara a pasta de download
    Write-Step "Preparando pasta temporaria de download ($DownloadFolder)..."
    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }
 
    # 3. Descobre a versao mais recente via API do GitHub
    Write-Step "Consultando a versao mais recente do Git for Windows..."
    $apiUrl = "https://api.github.com/repos/git-for-windows/git/releases/latest"
    $headers = @{ "User-Agent" = "installGit-script" }
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
 
    # Procura o asset do instalador 64-bit (ex: Git-2.46.0-64-bit.exe)
    $asset = $release.assets | Where-Object { $_.name -match '^Git-.*-64-bit\.exe$' } | Select-Object -First 1
 
    if (-not $asset) {
        throw "Nao foi possivel encontrar o instalador 64-bit na release mais recente."
    }
 
    $downloadUrl  = $asset.browser_download_url
    $installerPath = Join-Path $DownloadFolder $asset.name
 
    Write-Host "Versao encontrada: $($release.tag_name)" -ForegroundColor Green
 
    # 4. Baixa o instalador
    Write-Step "Downloading... ($($asset.name))"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
 
    if (-not (Test-Path $installerPath)) {
        throw "Falha ao baixar o instalador."
    }
    Write-Host "Download concluido: $installerPath" -ForegroundColor Green
 
    # 5. Instala silenciosamente
    # O instalador do Git for Windows usa Inno Setup, entao aceita estes parametros:
    #   /VERYSILENT        -> nenhuma janela visivel
    #   /NORESTART         -> nao reinicia o computador
    #   /NOCANCEL          -> impede cancelamento
    #   /SP-                -> nao mostra prompt inicial "This will install..."
    #   /SUPPRESSMSGBOXES  -> suprime caixas de mensagem
    #   /CLOSEAPPLICATIONS -> fecha apps que possam travar a instalacao
    #   /LOG               -> gera log da instalacao
    $logPath = Join-Path $DownloadFolder "git-install.log"
 
    Write-Step "Installing..."
    $installArgs = @(
        "/VERYSILENT",
        "/NORESTART",
        "/NOCANCEL",
        "/SP-",
        "/SUPPRESSMSGBOXES",
        "/CLOSEAPPLICATIONS",
        "/LOG=`"$logPath`""
    )
 
    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru
 
    if ($process.ExitCode -ne 0) {
        throw "A instalacao falhou com o codigo de saida $($process.ExitCode). Veja o log em $logPath"
    }
 
    Write-Host "Instalacao concluida com sucesso." -ForegroundColor Green
 
    # 6. Atualiza o PATH da sessao atual e verifica a instalacao
    Write-Step "Verificando a instalacao..."
    $gitDefaultPath = "$env:ProgramFiles\Git\cmd"
    if (Test-Path $gitDefaultPath) {
        $env:Path = "$gitDefaultPath;$env:Path"
    }
 
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $installedVersion = & git --version
        Write-Host "Sucesso! $installedVersion" -ForegroundColor Green
    }
    else {
        Write-Host "Git instalado, mas nao encontrado no PATH da sessao atual. Abra um novo terminal para usar o comando 'git'." -ForegroundColor Yellow
    }
 
    # 7. Limpeza opcional do instalador baixado
    Write-Step "Limpando arquivos temporarios..."
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
 
    Write-Host "Concluido." -ForegroundColor Cyan
}
catch {
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
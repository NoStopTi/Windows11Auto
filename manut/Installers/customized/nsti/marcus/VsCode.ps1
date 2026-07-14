<#
.SYNOPSIS
    Baixa e instala o Visual Studio Code (versao mais recente - stable) silenciosamente.

.DESCRIPTION
    - Baixa o instalador oficial mais atual via update.code.visualstudio.com
    - Executa a instalacao sem interacao do usuario (Inno Setup /VERYSILENT)
    - Exibe apenas mensagens de status (Downloading..., Installing..., etc)

.NOTES
    Por padrao baixa o instalador "System" (para todos os usuarios, x64).
    Use -Scope User para instalar apenas para o usuario atual (nao requer admin).
#>

[CmdletBinding()]
param(
    [ValidateSet("System", "User")]
    [string]$Scope = "System",

    [ValidateSet("x64", "arm64")]
    [string]$Arch = "x64",

    [string]$InstallerPath = "$env:TEMP\VSCodeSetup.exe"
)

$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

try {
    # 1) Monta a URL de download (sempre aponta para a build "stable" mais recente)
    $channel = if ($Scope -eq "User") { "win32-$Arch-user" } else { "win32-$Arch" }
    $DownloadUrl = "https://update.code.visualstudio.com/latest/$channel/stable"

    Write-Status "Downloading..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing
    $ProgressPreference = "Continue"

    if (-not (Test-Path $InstallerPath)) {
        throw "Falha ao baixar o instalador."
    }
    Write-Status "Download concluido."

    # 2) Instalacao silenciosa (instalador Inno Setup)
    Write-Status "Installing..."

    $installArgs = @(
        "/VERYSILENT",
        "/NORESTART",
        "/MERGETASKS=!runcode",     # nao abre o VS Code ao final da instalacao
        "/SUPPRESSMSGBOXES",
        "/LOG=$env:TEMP\VSCodeInstall.log"
    )

    $process = Start-Process -FilePath $InstallerPath -ArgumentList $installArgs -PassThru -Wait

    if ($process.ExitCode -ne 0) {
        throw "O instalador retornou codigo de saida $($process.ExitCode). Veja o log em $env:TEMP\VSCodeInstall.log"
    }
    Write-Status "Instalacao concluida."

    # 3) Limpeza
    Write-Status "Cleaning up..."
    Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue
    Write-Status "Concluido! Visual Studio Code foi instalado com sucesso."
}
catch {
    Write-Host "Erro: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
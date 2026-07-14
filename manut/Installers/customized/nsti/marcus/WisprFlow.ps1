<#
.SYNOPSIS
    Baixa e instala o Wispr Flow (versao mais recente) silenciosamente.

.DESCRIPTION
    - Baixa o instalador oficial mais atual a partir de dl.wisprflow.ai/windows/latest
    - Executa a instalacao sem interacao do usuario
    - Exibe apenas mensagens de status (Downloading..., Installing..., etc)

.NOTES
    O instalador do Wispr Flow para Windows e baseado em Squirrel e roda por padrao
    de forma nao-interativa (sem assistente de instalacao). Este script apenas
    automatiza o download + execucao e suprime saidas desnecessarias no console.
    A instalacao e feita por usuario, em %LOCALAPPDATA%\WisprFlow.
#>

[CmdletBinding()]
param(
    [string]$DownloadUrl = "https://dl.wisprflow.ai/windows/latest",
    [string]$InstallerPath = "$env:TEMP\WisprFlowSetup.exe"
)

$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

try {
    # 1) Download
    Write-Status "Downloading..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $ProgressPreference = "SilentlyContinue"  # acelera o Invoke-WebRequest
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $InstallerPath -UseBasicParsing
    $ProgressPreference = "Continue"

    if (-not (Test-Path $InstallerPath)) {
        throw "Falha ao baixar o instalador."
    }
    Write-Status "Download concluido."

    # 2) Instalacao silenciosa
    Write-Status "Installing..."

    # O instalador (Squirrel) roda sem UI por padrao ao ser executado normalmente.
    $process = Start-Process -FilePath $InstallerPath -PassThru -WindowStyle Hidden

    if ($process.ExitCode -ne 0) {
        throw "O instalador retornou codigo de saida $($process.ExitCode)."
    }
    Write-Status "Instalacao concluida."

    # 3) Limpeza
    Write-Status "Cleaning up..."
    Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue
    Write-Status "Concluido! Wispr Flow foi instalado com sucesso."
}
catch {
    Write-Host "Erro: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
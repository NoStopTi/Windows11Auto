<#
.SYNOPSIS
    Versiona manut\Core\machines.json (SemVer + build, estilo .NET/Windows: MAJOR.MINOR.PATCH.BUILD)
    e executa git add / commit / push.

.PARAMETER Message
    Mensagem do commit (obrigatório). Descreva o que foi feito.

.PARAMETER Type
    Tipo da alteração (obrigatório): MAJOR, MINOR, PATCH ou BUILD.
    - MAJOR: incrementa o 1º número e zera MINOR.PATCH.BUILD  (1.4.2.7 -> 2.0.0.0)
    - MINOR: incrementa o 2º número e zera PATCH.BUILD        (1.4.2.7 -> 1.5.0.0)
    - PATCH: incrementa o 3º número e zera BUILD               (1.4.2.7 -> 1.4.3.0)
    - BUILD: incrementa apenas o 4º número                     (1.4.2.7 -> 1.4.2.8)

.EXAMPLE
    .\Commit-Push.ps1 -Message "Corrige bug no Toggle-HiddenFiles" -Type BUILD
#>

param(
    [Parameter(Mandatory = $true)]
    [Alias("Mensagem")]
    [ValidateNotNullOrEmpty()]
    [string] $Message,

    [Parameter(Mandatory = $true)]
    [Alias("Tipo")]
    [ValidateSet("MAJOR", "MINOR", "PATCH", "BUILD")]
    [string] $Type
)

$ErrorActionPreference = "Stop"

function Write-Step([string] $text) {
    Write-Host "==> $text" -ForegroundColor Cyan
}

function Write-Ok([string] $text) {
    Write-Host "[OK] $text" -ForegroundColor Green
}

function Write-Fail([string] $text) {
    Write-Host "[ERRO] $text" -ForegroundColor Red
}

$repoRoot = $PSScriptRoot
$machinesJsonPath = Join-Path $repoRoot "manut\Core\machines.json"

if (-not (Test-Path (Join-Path $repoRoot ".git"))) {
    Write-Fail "Este script deve ficar na raiz do repositório git. Pasta '.git' não encontrada em '$repoRoot'."
    exit 1
}

if (-not (Test-Path $machinesJsonPath)) {
    Write-Fail "Arquivo de versão não encontrado em '$machinesJsonPath'."
    exit 1
}

# --- 1. Atualiza a versão em machines.json ---
Write-Step "Lendo versão atual de 'manut\Core\machines.json'..."

$machinesConfig = Get-Content -Path $machinesJsonPath -Raw | ConvertFrom-Json

$currentVersion = "1.0.0.0"
if ($machinesConfig.PSObject.Properties.Name -contains "version") {
    $currentVersion = $machinesConfig.version
}

$parts = $currentVersion -split '\.'
$numbers = @(0, 0, 0, 0)
for ($i = 0; $i -lt [Math]::Min(4, $parts.Length); $i++) {
    $numbers[$i] = [int]$parts[$i]
}

switch ($Type) {
    "MAJOR" {
        $numbers[0]++
        $numbers[1] = 0
        $numbers[2] = 0
        $numbers[3] = 0
    }
    "MINOR" {
        $numbers[1]++
        $numbers[2] = 0
        $numbers[3] = 0
    }
    "PATCH" {
        $numbers[2]++
        $numbers[3] = 0
    }
    "BUILD" {
        $numbers[3]++
    }
}

$newVersion = "{0}.{1}.{2}.{3}" -f $numbers[0], $numbers[1], $numbers[2], $numbers[3]

if ($machinesConfig.PSObject.Properties.Name -contains "version") {
    $machinesConfig.version = $newVersion
}
else {
    $machinesConfig | Add-Member -NotePropertyName "version" -NotePropertyValue $newVersion -Force
}

$json = $machinesConfig | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($machinesJsonPath, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Ok "Versão atualizada: $currentVersion -> $newVersion ($Type)"

# --- 2. git add / commit / push ---
Write-Step "git add ."
git -C $repoRoot add .
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Falha ao executar 'git add .'."
    exit 1
}

git -C $repoRoot diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Fail "Nada para commitar (nenhuma alteração detectada)."
    exit 1
}

Write-Step "git commit -m `"$Message`""
git -C $repoRoot commit -m $Message
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Falha ao executar 'git commit'."
    exit 1
}
Write-Ok "Commit criado."

Write-Step "git push"
git -C $repoRoot push
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Falha ao executar 'git push'."
    exit 1
}
Write-Ok "Push concluído."

Write-Host ""
Write-Ok "Concluído! Versão $newVersion publicada com a mensagem: `"$Message`""

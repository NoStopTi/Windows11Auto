<#
.SYNOPSIS
    Compara a versao de manut\Core\machines.json em C:\manut com a versao publicada
    no GitHub (commit mais recente da branch). Se a versao remota for maior, clona o
    repositorio em uma pasta temporaria e espelha (mirror) o conteudo para C:\manut
    e para qualquer pendrive "<letra>:\manut" encontrado.

.PARAMETER RepoUrl
    URL SSH do repositorio (padrao: git@github.com:NoStopTi/Windows11Auto.git).

.PARAMETER Branch
    Branch a comparar/clonar (padrao: main).

.EXAMPLE
    .\checkVersion.ps1
#>

param(
    [string] $RepoUrl = "git@github.com:NoStopTi/Windows11Auto.git",
    [string] $Branch = "main"
)

$ErrorActionPreference = "Stop"

$RelativeJsonPathGit = "manut/Core/machines.json"
$RelativeJsonPathFs  = "manut\Core\machines.json"
$RepoFolderName      = "Windows11Auto"
$TempCloneDir        = Join-Path $env:TEMP $RepoFolderName

function Write-Step([string] $text) { Write-Host "==> $text" -ForegroundColor Cyan }
function Write-Ok([string] $text)   { Write-Host "[OK] $text" -ForegroundColor Green }
function Write-Warn2([string] $text) { Write-Host "[AVISO] $text" -ForegroundColor Yellow }
function Write-Fail([string] $text) { Write-Host "[ERRO] $text" -ForegroundColor Red }

function Get-VersionNumbers([string] $versionString) {
    $numbers = @(0, 0, 0, 0)
    if ([string]::IsNullOrWhiteSpace($versionString)) {
        return $numbers
    }
    $parts = $versionString -split '\.'
    for ($i = 0; $i -lt [Math]::Min(4, $parts.Length); $i++) {
        $n = 0
        if ([int]::TryParse($parts[$i], [ref]$n)) {
            $numbers[$i] = $n
        }
    }
    return $numbers
}

function Compare-Versions([string] $a, [string] $b) {
    # retorna 1 se $a > $b, -1 se $a < $b, 0 se igual
    $va = Get-VersionNumbers $a
    $vb = Get-VersionNumbers $b
    for ($i = 0; $i -lt 4; $i++) {
        if ($va[$i] -gt $vb[$i]) { return 1 }
        if ($va[$i] -lt $vb[$i]) { return -1 }
    }
    return 0
}

function Get-PendriveTargets {
    # Varre B: e D:-Z: (A: e C: ficam de fora: A: e legado/lento, C: e o alvo principal
    # tratado separadamente) procurando pastas "<letra>:\manut" (pendrives).
    $targets = @()
    $letters = [char[]]([char]'B'..[char]'Z') | Where-Object { $_ -ne 'C' }
    foreach ($letter in $letters) {
        $candidate = "$letter`:\manut"
        try {
            if (Test-Path -LiteralPath $candidate -PathType Container -ErrorAction SilentlyContinue) {
                Write-Ok "Pendrive detectado: $candidate"
                $targets += $candidate
            }
        }
        catch {
            # unidade sem midia/inacessivel - ignora
        }
    }
    return $targets
}

function Get-LocalVersion([string] $manutPath) {
    $jsonPath = Join-Path $manutPath "Core\machines.json"
    if (-not (Test-Path $jsonPath)) {
        Write-Warn2 "'$jsonPath' nao existe. Tratando versao local como 0.0.0.0."
        return "0.0.0.0"
    }
    $localConfig = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
    if ($localConfig.PSObject.Properties.Name -contains "version") {
        return $localConfig.version
    }
    return "0.0.0.0"
}

# --- 1. Clone leve (sem checkout) so para ler a versao remota ---
Write-Step "Verificando versao remota em '$RepoUrl' (branch '$Branch')..."

if (Test-Path $TempCloneDir) {
    Remove-Item -LiteralPath $TempCloneDir -Recurse -Force
}

git clone --no-checkout --depth 1 --branch $Branch $RepoUrl $TempCloneDir
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Falha ao clonar '$RepoUrl'. Verifique a URL, o acesso SSH e a branch '$Branch'."
    exit 1
}

$remoteJsonRaw = git -C $TempCloneDir show "HEAD:$RelativeJsonPathGit" 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remoteJsonRaw)) {
    Write-Fail "Nao foi possivel ler '$RelativeJsonPathGit' no repositorio remoto."
    exit 1
}

$remoteConfig = $remoteJsonRaw | ConvertFrom-Json
$remoteVersion = "0.0.0.0"
if ($remoteConfig.PSObject.Properties.Name -contains "version") {
    $remoteVersion = $remoteConfig.version
}
Write-Ok "Versao remota: $remoteVersion"

# --- 2. Compara APENAS C:\manut com o remoto (fonte da verdade para a decisao) ---
$localVersion = Get-LocalVersion "C:\manut"
Write-Step "Versao local (C:\manut): $localVersion"

$cmp = Compare-Versions $remoteVersion $localVersion
if ($cmp -ne 1) {
    Write-Ok "C:\manut ja esta atualizado. Nada a fazer."
    Remove-Item -LiteralPath $TempCloneDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 0
}

Write-Warn2 "Versao remota ($remoteVersion) e mais nova que a local ($localVersion). Atualizando..."

# --- 3. Alvos a atualizar: C:\manut sempre + qualquer pendrive "<letra>:\manut" encontrado ---
$targetsToUpdate = @("C:\manut") + (Get-PendriveTargets)

# --- 4. Materializa o clone (checkout) agora que sabemos que havera atualizacao ---
Write-Step "Baixando conteudo completo da versao $remoteVersion..."
git -C $TempCloneDir checkout $Branch
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Falha ao materializar o clone (git checkout)."
    exit 1
}
Write-Ok "Clone completo em '$TempCloneDir'."

# --- 5. Espelha (mirror) o clone para cada destino desatualizado ---
foreach ($target in $targetsToUpdate) {
    Write-Step "Atualizando '$target' (mirror)..."
    robocopy $TempCloneDir $target /MIR /XD ".git" /R:2 /W:2 /NFL /NDL | Out-Null
    if ($LASTEXITCODE -ge 8) {
        Write-Fail "Robocopy falhou ao atualizar '$target' (codigo $LASTEXITCODE)."
    }
    else {
        Write-Ok "'$target' atualizado para a versao $remoteVersion."
    }
}

# --- 6. Limpeza ---
Remove-Item -LiteralPath $TempCloneDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Ok "Concluido! $($targetsToUpdate.Count) destino(s) atualizado(s) para a versao $remoteVersion."

<#
.SYNOPSIS
    Instala todas as atualizacoes do Windows (e de outros produtos Microsoft),
    reiniciando e repetindo o ciclo sozinho ate nao sobrar nenhuma.

.DESCRIPTION
    Usa a API COM nativa do Windows Update (Microsoft.Update.Session), sem
    modulos externos (PSWindowsUpdate) nem acesso ao PowerShell Gallery.

    Cada execucao e um ciclo:
      1. Busca as atualizacoes pendentes (Windows, Office, drivers...).
      2. Baixa e instala uma a uma, aceitando as licencas (EULA).
      3. Se precisar reiniciar: liga o auto login, se registra na RunOnce e
         reinicia. Apos o logon automatico o proximo ciclo comeca sozinho.
      4. Quando nao ha mais atualizacoes nem reinicio pendente: desliga o
         auto login, limpa a RunOnce e grava um resumo no log.

    O script se copia para C:\ProgramData\WinUpdateAuto\, e a RunOnce aponta
    sempre para essa copia. Logs e estado (state.json) ficam na mesma pasta.

    A senha do auto login nunca vai para a linha de comando da RunOnce: e
    lida de -Password/-Credential, do .env do projeto (ADM01_PASSWORD) ou,
    nos ciclos seguintes, da configuracao de auto login ja gravada.

.PARAMETER Username
    Conta usada no auto login entre os ciclos (padrao: ADM01).

.PARAMETER Password
    Senha da conta. Se omitida, e lida de ADM01_PASSWORD no .env.

.PARAMETER Credential
    Alternativa a -Username/-Password.

.PARAMETER Domain
    Dominio da conta. Padrao: nome do computador (ja considerando uma
    renomeacao pendente, que so vale apos o reinicio).

.PARAMETER MaxCycles
    Numero maximo de ciclos (reinicios). Ao atingir, o script faz a limpeza
    e para, evitando loop infinito com uma atualizacao que sempre falha.

.PARAMETER EnvFilePath
    Arquivo .env com ADM01_PASSWORD.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Update-Windows.ps1
    Usa a conta ADM01 com a senha do .env.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Update-Windows.ps1 -Username Administrador -Password '...'

.NOTES
    Precisa rodar como administrador e elevado; nunca abre janela de UAC.
    Enquanto o processo roda, DefaultPassword fica legivel no registro
    (mesmo comportamento do Enable-AutoLogon do projeto); e removida ao final
    e tambem em caso de erro fatal.
    Chamado no final do finishing.ps1 (ultimo passo da pos-formatacao).
#>

[CmdletBinding()]
param(
    [string] $Username = "ADM01",
    [string] $Password,
    [System.Management.Automation.PSCredential] $Credential,
    [string] $Domain,
    [int] $MaxCycles = 15,
    [string] $EnvFilePath = "C:\manut\Core\secure\.env"
)

$ErrorActionPreference = "Stop"

$WorkDir      = "C:\ProgramData\WinUpdateAuto"
$FixedScript  = Join-Path $WorkDir "Update-Windows.ps1"
$LogDir       = Join-Path $WorkDir "logs"
$LogFile      = Join-Path $LogDir "WinUpdateAuto.log"
$StateFile    = Join-Path $WorkDir "state.json"
$RunOnceKey   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
$RunOnceName  = "WinUpdateAuto"
$WinlogonKey  = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$MicrosoftUpdateServiceId = "7971f918-a847-4430-9279-4a52d1efe18d"
$MaxConsecutiveFailures = 3

# ResultCode da API do Windows Update (OperationResultCode)
$ResultCodeNames = @{ 0 = "NaoIniciado"; 1 = "EmAndamento"; 2 = "Sucesso"; 3 = "SucessoComErros"; 4 = "Falha"; 5 = "Abortado" }

function Write-Log {
    param([string] $Message, [string] $Level = "INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

function Test-IsElevated {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Estado (state.json) -----------------------------------------------------

function New-UpdateState {
    return @{
        Cycle     = 0
        StartedAt = (Get-Date).ToString("s")
        Completed = $false
        Installed = @()
        Failed    = @()
        # UpdateID -> numero de ciclos seguidos em que falhou
        FailureStreak = @{}
    }
}

function Get-UpdateState {
    if (-not (Test-Path $StateFile)) { return New-UpdateState }
    try {
        $raw = Get-Content -Path $StateFile -Raw | ConvertFrom-Json
    }
    catch {
        Write-Log "state.json ilegivel; iniciando um estado novo." "WARN"
        return New-UpdateState
    }
    # Execucao anterior ja concluida: esta e uma nova rodada
    if ($raw.Completed) { return New-UpdateState }

    $streak = @{}
    if ($raw.FailureStreak) {
        foreach ($p in $raw.FailureStreak.PSObject.Properties) { $streak[$p.Name] = [int]$p.Value }
    }
    return @{
        Cycle         = [int]$raw.Cycle
        StartedAt     = $raw.StartedAt
        Completed     = $false
        Installed     = @($raw.Installed | Where-Object { $_ })
        Failed        = @($raw.Failed | Where-Object { $_ })
        FailureStreak = $streak
    }
}

function Save-UpdateState([hashtable] $State) {
    $State | ConvertTo-Json -Depth 6 | Set-Content -Path $StateFile -Encoding UTF8
}

# --- Auto login e RunOnce ----------------------------------------------------

function Get-EnvValue([string] $Path, [string] $Key) {
    if (-not (Test-Path $Path)) { return $null }
    $line = Get-Content -Path $Path | Where-Object { $_ -match "^\s*$Key\s*=" } | Select-Object -First 1
    if ($line) { return ($line -split '=', 2)[1] }
    return $null
}

function Get-TargetComputerName {
    # Rename-Computer so vale apos reiniciar; o auto login precisa do nome novo
    $pending = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" -ErrorAction SilentlyContinue).ComputerName
    if ($pending) { return $pending }
    return $env:COMPUTERNAME
}

function Enable-UpdateAutoLogon {
    param([string] $User, [string] $Pass, [string] $UserDomain)

    if ([string]::IsNullOrEmpty($Pass)) {
        # Ciclos seguintes rodam pela RunOnce sem parametros: reaproveita o que ja esta gravado
        $current = Get-ItemProperty -Path $WinlogonKey -ErrorAction SilentlyContinue
        if ($current.AutoAdminLogon -eq "1" -and $current.DefaultPassword) {
            Set-ItemProperty -Path $WinlogonKey -Name "DefaultDomainName" -Value $UserDomain -Type String
            Write-Log "Auto login mantido para '$($current.DefaultUserName)'."
            return $true
        }
        Write-Log "Sem senha para o auto login (nem -Password, nem ADM01_PASSWORD no .env)." "ERROR"
        return $false
    }

    Set-ItemProperty -Path $WinlogonKey -Name "AutoAdminLogon"    -Value "1"         -Type String
    Set-ItemProperty -Path $WinlogonKey -Name "DefaultUserName"   -Value $User       -Type String
    Set-ItemProperty -Path $WinlogonKey -Name "DefaultDomainName" -Value $UserDomain -Type String
    Set-ItemProperty -Path $WinlogonKey -Name "DefaultPassword"   -Value $Pass       -Type String
    # AutoLogonCount zerado faz o Winlogon apagar o auto login no proximo boot
    Remove-ItemProperty -Path $WinlogonKey -Name "AutoLogonCount" -ErrorAction SilentlyContinue
    Write-Log "Auto login configurado para '$UserDomain\$User'."
    return $true
}

function Disable-UpdateAutoLogon {
    Set-ItemProperty -Path $WinlogonKey -Name "AutoAdminLogon" -Value "0" -Type String -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $WinlogonKey -Name "DefaultPassword" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $WinlogonKey -Name "AutoLogonCount" -ErrorAction SilentlyContinue
}

function Register-UpdateRunOnce {
    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$FixedScript`""
    Set-ItemProperty -Path $RunOnceKey -Name $RunOnceName -Value $command -Type String
    Write-Log "Registrado na RunOnce: $command"
}

function Unregister-UpdateRunOnce {
    Remove-ItemProperty -Path $RunOnceKey -Name $RunOnceName -ErrorAction SilentlyContinue
}

# --- Rede e servico -----------------------------------------------------------

function Wait-Network([int] $TimeoutSeconds = 300) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-WebRequest -Uri "http://www.msftconnecttest.com/connecttest.txt" -UseBasicParsing -TimeoutSec 5
            if ($r.Content -eq "Microsoft Connect Test") { return $true }
        }
        catch { }
        Write-Log "Aguardando rede..."
        Start-Sleep -Seconds 10
    }
    return $false
}

function Start-UpdateService {
    $svc = Get-Service -Name wuauserv
    if ($svc.StartType -eq "Disabled") {
        Set-Service -Name wuauserv -StartupType Manual
    }
    if ($svc.Status -ne "Running") {
        Start-Service -Name wuauserv
    }
    Write-Log "Servico wuauserv em execucao."
}

# --- Windows Update (COM) ----------------------------------------------------

function Register-MicrosoftUpdateService {
    # Inclui Office, drivers e outros produtos Microsoft, alem do Windows
    try {
        $manager = New-Object -ComObject Microsoft.Update.ServiceManager
        $manager.ClientApplicationID = "WinUpdateAuto"
        # 7 = permite registro pendente + online + registra no Automatic Updates
        $manager.AddService2($MicrosoftUpdateServiceId, 7, "") | Out-Null
        Write-Log "Servico Microsoft Update registrado."
        return $true
    }
    catch {
        Write-Log "Nao foi possivel registrar o Microsoft Update; buscando so no Windows Update. $_" "WARN"
        return $false
    }
}

function Get-UpdateLabel($Update) {
    $kb = @($Update.KBArticleIDs) | Select-Object -First 1
    if ($kb) { return "KB$kb - $($Update.Title)" }
    return $Update.Title
}

function Find-PendingUpdates($Session, [bool] $UseMicrosoftUpdate) {
    $searcher = $Session.CreateUpdateSearcher()
    if ($UseMicrosoftUpdate) {
        # 3 = ssOthers: busca direto no Microsoft Update, mesmo que exista WSUS configurado
        $searcher.ServerSelection = 3
        $searcher.ServiceID = $MicrosoftUpdateServiceId
    }
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Write-Log "Buscando atualizacoes (tentativa $attempt de 3)..."
            return $searcher.Search("IsInstalled=0 and IsHidden=0")
        }
        catch {
            Write-Log "Falha na busca: $_" "WARN"
            if ($attempt -lt 3) { Start-Sleep -Seconds 30 }
        }
    }
    throw "A busca de atualizacoes falhou 3 vezes."
}

function Install-SingleUpdate($Session, $Update) {
    # Uma atualizacao por vez: uma falha (ou excecao) nao interrompe o lote,
    # e atualizacoes que exigem instalacao exclusiva funcionam
    $collection = New-Object -ComObject Microsoft.Update.UpdateColl
    $collection.Add($Update) | Out-Null

    if (-not $Update.IsDownloaded) {
        $downloader = $Session.CreateUpdateDownloader()
        $downloader.Updates = $collection
        $download = $downloader.Download()
        $code = $download.GetUpdateResult(0).ResultCode
        Write-Log "  Download: $($ResultCodeNames[[int]$code])"
        if ($code -ne 2 -and $code -ne 3) {
            return @{ ResultCode = [int]$code; HResult = $download.GetUpdateResult(0).HResult; RebootRequired = $false }
        }
    }

    $installer = $Session.CreateUpdateInstaller()
    $installer.ForceQuiet = $true
    $installer.Updates = $collection
    $install = $installer.Install()
    $result = $install.GetUpdateResult(0)
    return @{ ResultCode = [int]$result.ResultCode; HResult = $result.HResult; RebootRequired = [bool]$result.RebootRequired }
}

function Test-RebootPending {
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") { return $true }
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") { return $true }
    $sessionManager = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
    if ($sessionManager -and $sessionManager.PendingFileRenameOperations) { return $true }
    return $false
}

# --- Finalizacao -------------------------------------------------------------

function Complete-UpdateRun([hashtable] $State, [string] $Reason) {
    Disable-UpdateAutoLogon
    Unregister-UpdateRunOnce
    $State.Completed = $true
    Save-UpdateState $State

    Write-Log "============================================"
    Write-Log "  ATUALIZACAO CONCLUIDA: $Reason"
    Write-Log "  Ciclos: $($State.Cycle)"
    Write-Log "  Atualizacoes instaladas: $(@($State.Installed).Count)"
    foreach ($item in $State.Installed) { Write-Log "    + $item" }
    Write-Log "  Falhas: $(@($State.Failed).Count)"
    foreach ($item in $State.Failed) { Write-Log "    - $item" "WARN" }
    Write-Log "  Auto login desligado e RunOnce limpa."
    Write-Log "============================================"
}

# =============================================================================
# Execucao
# =============================================================================

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

if (-not (Test-IsElevated)) {
    Write-Log "O script precisa rodar como administrador e elevado. Encerrando." "ERROR"
    exit 1
}

# Copia para o local fixo usado pela RunOnce
if ($PSCommandPath -and ($PSCommandPath -ne $FixedScript)) {
    Copy-Item -Path $PSCommandPath -Destination $FixedScript -Force
}

$transcript = Join-Path $LogDir ("transcript_{0:yyyy-MM-dd_HHmmss}.txt" -f (Get-Date))
Start-Transcript -Path $transcript -Force | Out-Null

$rebootScheduled = $false
$state = $null

try {
    $state = Get-UpdateState
    $state.Cycle++
    Save-UpdateState $state

    Write-Log "============================================"
    Write-Log "  WINDOWS UPDATE AUTOMATICO - CICLO $($state.Cycle) de no maximo $MaxCycles"
    Write-Log "============================================"

    if ($state.Cycle -gt $MaxCycles) {
        Complete-UpdateRun -State $state -Reason "limite de $MaxCycles ciclos atingido"
        return
    }

    # Credenciais do auto login: parametros > .env > configuracao ja gravada
    if ($Credential) {
        $Username = $Credential.UserName
        $Password = $Credential.GetNetworkCredential().Password
    }
    if ([string]::IsNullOrEmpty($Password)) {
        $Password = Get-EnvValue -Path $EnvFilePath -Key "ADM01_PASSWORD"
    }
    if ([string]::IsNullOrEmpty($Domain)) {
        $Domain = Get-TargetComputerName
    }

    if (-not (Wait-Network)) {
        Write-Log "Sem rede apos 5 minutos." "WARN"
    }
    Start-UpdateService

    $session = New-Object -ComObject Microsoft.Update.Session
    $session.ClientApplicationID = "WinUpdateAuto"
    $useMicrosoftUpdate = Register-MicrosoftUpdateService

    $rebootRequired = $false
    # Atualizacoes que falharam nesta execucao: so sao tentadas de novo apos reiniciar
    $failedThisRun = @{}

    # Instalar algumas atualizacoes pode revelar outras que dependiam delas:
    # busca de novo na mesma execucao enquanto houver algo novo instalado
    do {
        $search = Find-PendingUpdates -Session $session -UseMicrosoftUpdate $useMicrosoftUpdate
        Write-Log "Atualizacoes encontradas: $($search.Updates.Count)"
        $installedThisPass = 0

        for ($i = 0; $i -lt $search.Updates.Count; $i++) {
            $update = $search.Updates.Item($i)
            $id = $update.Identity.UpdateID
            $label = Get-UpdateLabel $update

            if ($failedThisRun.ContainsKey($id)) { continue }
            if ([int]$state.FailureStreak[$id] -ge $MaxConsecutiveFailures) {
                Write-Log "Pulando (falhou $MaxConsecutiveFailures ciclos seguidos): $label" "WARN"
                continue
            }
            if ($update.InstallationBehavior.CanRequestUserInput) {
                Write-Log "Pulando (pode pedir interacao do usuario): $label" "WARN"
                continue
            }

            Write-Log "Instalando: $label"
            try {
                if (-not $update.EulaAccepted) { $update.AcceptEula() }
                $result = Install-SingleUpdate -Session $session -Update $update
            }
            catch {
                $result = @{ ResultCode = 4; HResult = $_.Exception.HResult; RebootRequired = $false }
                Write-Log "  Excecao: $_" "WARN"
            }

            Write-Log ("  Resultado: {0} (HResult 0x{1:X8})" -f $ResultCodeNames[$result.ResultCode], $result.HResult)
            if ($result.RebootRequired) { $rebootRequired = $true }

            if ($result.ResultCode -eq 2 -or $result.ResultCode -eq 3) {
                $state.Installed += $label
                $state.FailureStreak.Remove($id)
                $installedThisPass++
            }
            else {
                $failedThisRun[$id] = $true
                $state.FailureStreak[$id] = 1 + [int]$state.FailureStreak[$id]
                if ($state.FailureStreak[$id] -ge $MaxConsecutiveFailures) {
                    $state.Failed += "$label (desistiu apos $MaxConsecutiveFailures ciclos)"
                }
            }
            Save-UpdateState $state
        }
    } while ($installedThisPass -gt 0 -and -not $rebootRequired)

    if (Test-RebootPending) { $rebootRequired = $true }

    # Falhas que ainda nao atingiram o limite: muitas so instalam depois de reiniciar
    $retryable = @($failedThisRun.Keys | Where-Object { [int]$state.FailureStreak[$_] -lt $MaxConsecutiveFailures }).Count

    if ($rebootRequired -or $retryable -gt 0) {
        if (-not (Enable-UpdateAutoLogon -User $Username -Pass $Password -UserDomain $Domain)) {
            Complete-UpdateRun -State $state -Reason "nao foi possivel configurar o auto login"
            return
        }
        Register-UpdateRunOnce
        Save-UpdateState $state
        $rebootScheduled = $true
        Write-Log "Reiniciando para continuar no ciclo $($state.Cycle + 1)..."
        Stop-Transcript | Out-Null
        Restart-Computer -Force
        return
    }

    Complete-UpdateRun -State $state -Reason "nenhuma atualizacao pendente"
}
catch {
    Write-Log "Erro fatal: $_" "ERROR"
    if ($state) {
        $state.Failed += "Erro fatal no ciclo $($state.Cycle): $_"
        Complete-UpdateRun -State $state -Reason "erro fatal"
    }
    exit 1
}
finally {
    # Nunca deixa a senha exposta no registro, a nao ser que o reinicio do proximo ciclo esteja agendado
    if (-not $rebootScheduled) {
        Disable-UpdateAutoLogon
        Unregister-UpdateRunOnce
        try { Stop-Transcript | Out-Null } catch { }
    }
}

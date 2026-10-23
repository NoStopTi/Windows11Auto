# Windows11Auto

## Atualizacao automatica do Windows (`Update-Windows.ps1`)

`manut\Configurations\Update-Windows.ps1` e o ultimo passo da pos-formatacao:
o `finishing.ps1` o chama depois de configurar contas e nome do computador.

Ele busca, baixa e instala todas as atualizacoes (Windows, Office, drivers e
outros produtos Microsoft) sem interacao. Quando precisa reiniciar, liga o auto
login, se registra na `RunOnce` e reinicia; o ciclo se repete ate nao sobrar
nenhuma atualizacao. No fim, desliga o auto login e limpa a `RunOnce`.

- Copia de trabalho, estado e logs: `C:\ProgramData\WinUpdateAuto\`
  (`logs\WinUpdateAuto.log` consolidado + um transcript por ciclo, `state.json`).
- Senha do auto login: `ADM01_PASSWORD` do `.env` (nunca vai para a `RunOnce`).
- Protecoes: no maximo 15 ciclos (`-MaxCycles`); uma atualizacao que falha em
  3 ciclos seguidos deixa de ser tentada; em erro fatal o auto login e removido.

Uso manual (PowerShell como administrador):

```powershell
# Conta ADM01 com a senha do .env
powershell -ExecutionPolicy Bypass -File .\Update-Windows.ps1

# Outra conta
powershell -ExecutionPolicy Bypass -File .\Update-Windows.ps1 -Username Administrador -Password '...'
```

Rodar numa maquina ja atualizada termina sem reiniciar.

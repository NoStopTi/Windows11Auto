# Instruções para esta pasta

Esta pasta (`manut\Installers\customized\nsti\marcus`) contém scripts `.ps1` de instalação de aplicativos referenciados pelo arquivo central:

`manut\Core\machines.json` (caminho relativo à raiz do repositório — **não** assuma a letra de unidade `D:`; localize a raiz do repo a partir do diretório de trabalho atual, ela pode estar em qualquer unidade/pasta).

## Regra obrigatória

**Toda vez que um novo arquivo `.ps1` for criado nesta pasta, você deve atualizar `machines.json` no mesmo momento**, adicionando uma referência a esse arquivo dentro do array `"apps"` da(s) máquina(s) que já usam scripts desta pasta (procure por entradas cujo `path` contenha `customized\nsti\marcus`).

Isso vale mesmo que a criação do arquivo não tenha sido pedida explicitamente para atualizar o JSON — a atualização é parte da tarefa por padrão.

## Como adicionar a entrada

1. Abra `manut\Core\machines.json` a partir da raiz do repositório (não hardcode `D:\...`; use o caminho relativo ou resolva a raiz do repo dinamicamente, já que o projeto pode estar em outra unidade/máquina).
2. Localize o(s) objeto(s) de máquina (`machines[].apps`) que já referenciam a pasta `customized\nsti\marcus`.
3. Adicione um novo objeto ao array `"apps"` no formato:

```json
{
  "appName": "NomeDoArquivo",
  "path": ".\\Installers\\customized\\nsti\\marcus\\NomeDoArquivo.ps1"
}
```

### Convenções de formatação (siga exatamente o padrão existente)

- `appName`: nome do app/script, geralmente igual ao nome do arquivo sem a extensão `.ps1` (ex.: `Git.ps1` → `"Git"`, `WixToolsetDotnet.ps1` → `"WixToolsetDotnet"`).
- `path`: caminho relativo começando com `.\Installers\...` (barra invertida dupla no JSON, **com** o prefixo `.\` — diferente das entradas de `configs`, que não usam esse prefixo). Use exatamente o mesmo estilo de caminho já presente nas entradas de `apps`.
- Mantenha o JSON válido: sem vírgula sobrando no último elemento do array, indentação de 2 espaços consistente com o resto do arquivo.

### Exemplo prático

Se for criado `Docker.ps1` nesta pasta, o array `apps` da máquina correspondente deve passar de:

```json
"apps": [
  {
    "appName": "Git",
    "path": ".\\Installers\\customized\\nsti\\marcus\\Git.ps1"
  }
]
```

para:

```json
"apps": [
  {
    "appName": "Git",
    "path": ".\\Installers\\customized\\nsti\\marcus\\Git.ps1"
  },
  {
    "appName": "Docker",
    "path": ".\\Installers\\customized\\nsti\\marcus\\Docker.ps1"
  }
]
```

## Observações

- Se houver mais de uma máquina/empresa no `machines.json` que também referencie esta pasta, adicione a entrada em **todas** elas.
- Se nenhuma máquina ainda referenciar esta pasta, pergunte ao usuário em qual `uuid`/empresa a entrada deve ser adicionada antes de editar.
- Não crie arquivos duplicados de instalador nem entradas duplicadas em `machines.json` para o mesmo script.

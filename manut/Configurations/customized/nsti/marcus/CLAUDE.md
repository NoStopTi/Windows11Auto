# Instruções para esta pasta

Esta pasta (`manut\Configurations\customized\nsti\marcus`) contém scripts `.ps1` de configuração referenciados pelo arquivo central:

`manut\Core\machines.json` (caminho relativo à raiz do repositório — **não** assuma a letra de unidade `D:`; localize a raiz do repo a partir do diretório de trabalho atual, ela pode estar em qualquer unidade/pasta).

## Regra obrigatória

**Toda vez que um novo arquivo `.ps1` for criado nesta pasta, você deve atualizar `machines.json` no mesmo momento**, adicionando uma referência a esse arquivo dentro do array `"configs"` da(s) máquina(s) que já usam scripts desta pasta (procure por entradas cujo `path` contenha `customized\nsti\marcus`).

Isso vale mesmo que a criação do arquivo não tenha sido pedida explicitamente para atualizar o JSON — a atualização é parte da tarefa por padrão.

## Como adicionar a entrada

1. Abra `manut\Core\machines.json` a partir da raiz do repositório (não hardcode `D:\...`; use o caminho relativo ou resolva a raiz do repo dinamicamente, já que o projeto pode estar em outra unidade/máquina).
2. Localize o(s) objeto(s) de máquina (`machines[].configs`) que já referenciam a pasta `customized\nsti\marcus`.
3. Adicione um novo objeto ao array `"configs"` no formato:

```json
{
  "confName": "NomeDoArquivo",
  "path": "\\Configurations\\customized\\nsti\\marcus\\NomeDoArquivo.ps1"
}
```

### Convenções de formatação (siga exatamente o padrão existente)

- `confName`: nome do arquivo sem a extensão `.ps1` (ex.: `Toggle-HiddenFiles.ps1` → `"HideFiles"` foi usado como nome descritivo curto — prefira um nome curto e descritivo da função do script, não necessariamente idêntico ao filename).
- `path`: caminho relativo começando com `\Configurations\...` (barra invertida dupla no JSON, **sem** o prefixo `.\` que é usado nos `apps`). Use exatamente o mesmo estilo de caminho já presente nas entradas de `configs`.
- Mantenha o JSON válido: sem vírgula sobrando no último elemento do array, indentação de 2 espaços consistente com o resto do arquivo.

### Exemplo prático

Se for criado `test.ps1` nesta pasta, o array `configs` da máquina correspondente deve passar de:

```json
"configs": [
  {
    "confName": "HideFiles",
    "path": "\\Configurations\\customized\\nsti\\marcus\\Toggle-HiddenFiles.ps1"
  }
]
```

para:

```json
"configs": [
  {
    "confName": "HideFiles",
    "path": "\\Configurations\\customized\\nsti\\marcus\\Toggle-HiddenFiles.ps1"
  },
  {
    "confName": "Tests",
    "path": "\\Configurations\\customized\\nsti\\marcus\\test.ps1"
  }
]
```

## Observações

- Se houver mais de uma máquina/empresa no `machines.json` que também referencie esta pasta, adicione a entrada em **todas** elas.
- Se nenhuma máquina ainda referenciar esta pasta, pergunte ao usuário em qual `uuid`/empresa a entrada deve ser adicionada antes de editar.
- Não crie arquivos duplicados de configuração nem entradas duplicadas em `machines.json` para o mesmo script.

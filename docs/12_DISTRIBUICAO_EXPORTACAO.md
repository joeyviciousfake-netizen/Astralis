# 12 — EMPACOTAMENTO E DISTRIBUIÇÃO

> O que existe hoje é o **`.apack`**: o arquivo único de criação de pack. A
> distribuição trancada (`.astralis`) é **PLANO** e está marcada como tal no fim.
> As duas implementações do `.apack` (Python e Rust) precisam bater; o GUT e o
> `cargo test` cobrem o round-trip.

## 12.1 OS DOIS FORMATOS (o que existe, e o que é plano)

| | Formato | Estado |
|---|---|---|
| **Trabalho** | pasta JSON, lida pelo jogo via `--project` | **existe** |
| **Criação** | `.apack` — zip com texto e imagens num arquivo só | **existe** |
| **Distribuição** | `.astralis` binário, com cadeado por jogo | **PLANO, 0%** |

O `.apack` **não** é a fita de distribuição: é o pack que o autor cria e outro
autor importa. Ele é aberto — não tem chave nem assinatura. O `pack` é um
projeto de edição; a fita trancada é o que o usuário final receberia.

## 12.2 O FORMATO DE TRABALHO (o que o jogo lê)

O esqueleto de projeto tem 8 pastas versionadas e 2 arquivos:

```text
cards/  duelists/  decks/  scenes/  layouts/
assets/cards/  assets/portraits/  assets/backgrounds/
fusions.json   effects.json          <- arquivos, nao pastas
```

Não existe `project.json`: a versão mora no `manifest` do `.apack` e o resto é
conferido pelos schemas. Também não existem pastas `fusions/`, `effects/`,
`campaigns/` nem `tests/` — as duas primeiras viraram arquivos, e as outras duas
nunca existiram.

**O dono do esqueleto é `PASTAS_ESQUELETO` em `astralis-studio/src-tauri/src/main.rs`**, e ele garante um `.gitkeep` em cada pasta. O `.gitkeep` não é conteúdo: é o marcador que mantém a pasta rastreável, sem ele abrir o Studio suja o repositório.

`fusions.json` e `effects.json` **nascem vazios**. Fusão vazia é normal (o jogo
funciona sem receita). Efeito vazio é aviso, não erro: o gate diz onde cadastrar.

## 12.3 O `.apack` (V1, o contrato)

Um **zip comum** (deflate, que abre em qualquer lib: `zipfile` do Python, crate
`zip` do Rust, 7-Zip). O "nosso" é a extensão, o `manifest.json` e as regras —
**nenhum algoritmo inventado**.

```text
meu_pack.apack
  manifest.json        <- metadados e SHA-256 de cada arquivo
  data/pack.json       <- o pack, byte-idêntico ao JSON legado
  assets/...           <- imagens, deduplicadas por hash
  preview.png          <- opcional (png, jpg ou webp; 2 MB)
```

### `manifest.json` (campo a mais ou a menos = `.apack` inválido)

| Campo | Regra |
|---|---|
| `magic` | `"APACK"`, exato |
| `format_version` | `1` |
| `mode` | só `"aberto"` (o `"protegido"` é recusado) |
| `author_id` | string |
| `created_at` | ISO-8601 |
| `preview` | nome do arquivo de preview, ou ausente |
| `files[]` | `path` (dentro do zip), `sha256`, `bytes`, e `stored_as` quando o arquivo foi deduplicado |
| `pack_sha256` | SHA-256 do `data/pack.json` |

### As 6 regras

1. **Referência por caminho estável.** `artwork` aponta para `assets/...`, e é o
   caminho dentro do zip. Renomear no disco não quebra o pack.
2. **Dedup por SHA-256.** Dois arquivos idênticos são gravados uma vez, e cada
   entrada aponta para o mesmo `stored_as`.
3. **Faltando é AVISO, não erro.** Arte que não está no zip abre o pack como
   "sem imagens", e o jogo mostra placeholder cinza.
4. **Pack legado `.json` = `.apack` sem assets.** O `data/pack.json` é
   byte-idêntico ao JSON, e `pack_sha256` prova isso.
5. **ZipSlip vale para o zip E para o manifest**, nos dois lados. Caminho
   absoluto, com `..`, ou apontando para fora do zip é recusado — e o `check`
   recusa **antes** de materializar qualquer arquivo.
6. **Limites:** 5 MB por asset, 200 MB de assets somados, 250 MB no arquivo final,
   5.000 arquivos. As mesmas constantes estão em `tools/apack.py` e em
   `astralis-studio/src-tauri/src/apack.rs` — se um mudar, o outro muda no mesmo
   commit, e a interop é provada por round-trip.

`schema_version` continua `1`: o `.apack` é só transporte novo, **nenhum campo do
contrato mudou** e não há migração. É por isso que ele pode existir sem tocar em
nenhum schema.

### O que o `check` recusa (`rc=1`)

`magic` diferente de `APACK` · `mode: "protegido"` · `format_version: 2` · hash de
qualquer arquivo que não bate · asset acima do teto · extensão fora da lista ·
`files[].path` ou `stored_as` fora do zip.

## 12.4 ONDE ESTÁ A IMPLEMENTAÇÃO

| Lado | Arquivo | O que faz |
|---|---|---|
| Python | `tools/apack.py` | `pack` embrulha, `check` valida, `unpack` desempacota conferindo hash |
| Rust | `astralis-studio/src-tauri/src/apack.rs` | o mesmo, pelo `crate zip` (deflate) e `sha2` |
| Editor | `main.rs` | `importar_apack` / `exportar_apack` |

O `importar_pack_valor` **não muda** por causa do `.apack`: mesmas chaves, mesmo
filtro, mesmo backup. O port do Rust passa o valor inteiro para ele.

## 12.5 DISTRIBUIÇÃO TRANCADA (PLANO, 0% implementado)

Isto é especificação, **não existe linha de código disto**. Nenhum `export_presets.cfg`,
nenhuma exportação Godot, nenhum `data.bin`, nenhuma assinatura.

O que seria:

- O `.astralis` é um arquivo binário (MessagePack + zlib + hash + assinatura), e
  o jogador nunca vê JSON de distribuição em texto (R6).
- O cadeado é por jogo: a chave é gerada no Exportar e embutida no player.
- Player e fita vão no mesmo zip, e o boot recusa se as versões divergirem.
- Win e Linux: `exe` + `.astralis` lado a lado. Android V1: `APK` + `.astralis`
  importado; fundido no APK só em V2.
- Limite honesto: trava cópia casual, não impede extração por quem olha memória.
  Por isso assinatura e autoria também são prova.

**O que decide isso:** biblioteca de serialização, assinatura, chave por jogo e
cache de player. O Studio hoje é honesto: valida e **avisa que não empacotou**.

## 12.6 DONOS

| Assunto | Dono |
|---|---|
| o formato do `.apack` e os schemas | Systems/Data |
| ler o projeto no jogo | Runtime |
| importar, exportar e a tela de Exportar | Editor |
| round-trip, `.apack` inválido, ZipSlip, limites | QA |

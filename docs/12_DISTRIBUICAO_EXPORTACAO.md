# 12 — DISTRIBUIÇÃO E EXPORTAÇÃO PROTEGIDA

VERSION: 1.4 (novo §12.7: pack de criação .apack V1)
STATUS: AUTHORITATIVE
ORIGEM: decisão de produto pós-v1.2 — fita + videogame juntos, com cadeado

## 12.1 Ideia simples

- Astralis = videogame. Exportado 1 vez pela equipe via Godot para Windows/Linux/Android.
- Jogo do usuário = fita `.astralis`. Não é JSON solto, é binário trancado.
- Exportar = colocar videogame + fita na mesma caixa (zip). Acaba o problema de versionamento, pois a versão certa vai junto.

Usuário nunca instala Godot. Studio nunca roda export Godot. Studio só copia o player certo que já está pronto.

## 12.2 Dois formatos (regra oficial)

1. TRABALHO (pasta JSON editável, git-friendly):
```text
meu-projeto/
  project.json (schema_version, runtime_version, author_id)
  cards/ duelists/ decks/ fusions/ effects/ campaigns/ assets/
```

2. DISTRIBUIÇÃO (`.astralis` único, binário, não abre no bloco de notas):
```text
ASTR magic + schema_version + runtime_version + author_id + flags
+ manifest (lista + SHA256 de cada recurso)
+ data.bin (MessagePack + zlib, sem nomes óbvios)
+ assets.bin (png/ogg empacotados)
+ assinatura Ed25519 + watermark author_id
```

Astralis carrega em memória, valida hash/assinatura/versões, nunca cospe JSON de volta. Se hash não bate ou versão difere, recusa com erro humano + orienta re-exportar.

## 12.3 Cadeado na hora do build (obrigatório no Protegido)

UX: checkbox `☑ Proteger contra cópia`. Tudo automático, sem senha digitada.

Na exportação o Studio:
1. gera chave única por jogo (cadeado + chave),
2. tranca a fita `.astralis` com ela (padrão de mercado AES/XChaCha, detalhe interno),
3. esconde a cópia da chave dentro do Astralis que vai na caixa.

Resultado:
- aquele Astralis abre aquela fita sem o jogador perceber,
- outro Astralis genérico não abre,
- abrir no editor de texto só mostra lixo,
- metadados de edição são removidos.

Limite honesto: trava 99% da cópia casual. Hacker avançado olhando memória sempre consegue extrair — nenhum formato impede 100%. Por isso temos também assinatura/autoria como prova.

Modos:
- Aberto (moddable): sem cadeado, só compactado + assinado. Bom para mods.
- Protegido (padrão p/ distribuir na internet): com cadeado como acima.

## 12.4 O que vai no zip por plataforma

Windows:
```text
MeuJogo-windows.zip
  MeuJogo.exe       <- Astralis win vX.Y com chave embutida
  MeuJogo.astralis  <- fita trancada
```

Linux:
```text
MeuJogo-linux.zip
  MeuJogo.x86_64
  MeuJogo.astralis
```

Android V1 (sem rebuild de APK):
```text
MeuJogo-android.zip
  Astralis.apk
  MeuJogo.astralis
```
Fluxo: instala APK, abre app, importa `.astralis` (V1 com auto-detecção em Download para parecer junto). Não exige SDK/keystore no PC do usuário.

Android V2 (APK fundido, instalar-e-jogar): requer build server com Godot headless + templates + assinatura. Adiado para não travar V1.

## 12.5 Versionamento junto

Cada `.astralis` carrega `schema_version + runtime_version + author_id`.
Cada player carrega sua `runtime_version`.
Check no boot: `se jogo.runtime != player.runtime -> erro + peça export com player certo`.

CI da equipe publica `astralis-player-win/linux/android-vX.Y` a cada release. Studio baixa/cacheia. Usuário só escolhe plataforma.

## 12.7 Pack de criação `.apack` V1 (D23, Systems)

O pack de criação vira ARQUIVO ÚNICO com extensão nossa `.apack`: textos +
imagens juntos. A fita final `.astralis` continua trancada (§12.2). São TRÊS
formatos, cada um com seu dono e sua hora:

| Formato | O quê | Quando |
|---|---|---|
| TRABALHO (pasta JSON editável, §12.2) | `project.json + cards/ duelists/ ... + assets/` | editando no dia a dia (git-friendly) |
| CRIAÇÃO (`.apack`, este §) | 1 zip aberto texto+imagens | passando o pack pra alguém / Importar no Studio |
| DISTRIBUIÇÃO (`.astralis`, §12.2) | 1 binário trancado | entregando o jogo pro jogador |

`.apack` é um ZIP comum (deflate, abre em qualquer lib: Python `zipfile`,
Rust `zip`, 7-Zip). O "nosso" é a extensão + `manifest.json` + regras —
NENHUM algoritmo inventado.

Estrutura exata do zip:

```text
meu-pack.apack
  manifest.json            <- magic APACK + versões + contagens + SHA256
  data/pack.json           <- O MESMO JSON legado (ex.: fm_original_pack.json)
  assets/...               <- png/webp/jpg/jpeg + ogg (só os referenciados)
  preview.{png,jpg,webp}   <- OPCIONAL, capa do pack (só desenho)
```

`manifest.json` (schema exato — campo a mais ou a menos = `.apack` inválido):

| Campo | Tipo | Regra |
|---|---|---|
| `magic` | string | sempre `"APACK"` |
| `format_version` | int | sempre `1` (V1) |
| `schema_version` | int | sempre `1` (o contrato NÃO mudou, sem migração) |
| `runtime_version` | string | info obrigatória, SEM trava V1 (a trava mora no boot do `.astralis`, §12.5) |
| `author_id` | string | info obrigatória, SEM trava V1 |
| `mode` | string | sempre `"aberto"` (trancado é `.astralis`, nunca `.apack`) |
| `pack_id` / `name` | string | copiados do `pack.json` (só exibição) |
| `counts` | objeto | `cartas/duelistas/decks/fusoes_recipes/fusoes_rules/equips/assets/assets_bytes` |
| `files[]` | lista | 1 por arquivo: `{path, sha256, size}` + `stored_as` quando repetida (abaixo) |
| `pack_sha256` | string | SHA256 dos bytes de `data/pack.json` (roundtrip = mesmo hash) |
| `created_utc` / `tool` | string | carimbo + gerador (só rastro) |

Mínimo válido:

```json
{"magic":"APACK","format_version":1,"schema_version":1,"runtime_version":"1",
 "author_id":"fm_original","mode":"aberto","pack_id":"fm_original_pack",
 "name":"FM Original Pack","counts":{"cartas":722,"duelistas":39,"decks":39,
 "fusoes_recipes":25131,"fusoes_rules":0,"equips":4041,"assets":0,"assets_bytes":0},
 "files":[{"path":"data/pack.json","sha256":"8bad78b0…","size":2743674}],
 "pack_sha256":"8bad78b0…","created_utc":"2026-09-25T00:00:00Z","tool":"tools/apack.py V1"}
```

Inválidos (o `check` recusa, `rc=1`): `magic:"XXXX"`; `mode:"protegido"`;
`schema_version:2`; hash de qualquer arquivo não batendo; asset acima do
teto; extensão fora da lista; `files[].path` ou `stored_as` fora do zip
(`../escape.txt`, absoluto, letra de unidade — regra 5).

Regras V1 (valem no Python e no port Rust):

1. Referência por path estável: tudo que no pack é string `assets/...`
   (hoje `artwork`, amanhã portraits/backgrounds) resolve dentro do zip.
2. Imagem repetida grava 1x: mesmo SHA256 = 1 entrada no zip; o manifest
   lista cada path lógico com `stored_as` apontando pro guardado; o unpack
   materializa TODAS as cópias.
3. Faltando = AVISO, não erro: pack sem a imagem abre como legado
   "sem imagens" (placeholder + aviso, igual hoje). As 722 do FM caem aqui.
4. Pack legado `.json` = `.apack` sem assets: embrulhar o `.json` não muda
   1 byte do dado (`pack_sha256` prova); o Importar conta igual.
5. Trava ZipSlip: entrada absoluta, com `..`, com letra de unidade
   (`C:...`) ou vazia = erro, nos dois lados — vale pros nomes do zip E
   pros `files[].path`/`stored_as` do manifest, no `check` e no `unpack`
   (espelho Python ↔ Rust `apack.rs:275-281`); nada é escrito antes de tudo validar.
6. Limites V1 (estourar = erro): 5 MB por asset; 200 MB assets somados;
   250 MB o `.apack`; máx 5000 assets; extensões `png/webp/jpg/jpeg/ogg`;
   preview máx 2 MB.

Compat: `schema_version` continua **1** — só formato de transporte novo,
nenhum campo do contrato mudou, nenhuma migração. O filtro das 50 `A+A`
continua no Importar (FM real: 25131 no pack → 25081 importáveis).

Port Rust (Editor, 5 passos, reutilizando o que já existe):

1. Abrir o zip (crate `zip`), ler `manifest.json`, recusar se `magic !=
   APACK` ou `format_version != 1`.
2. Conferir SHA256 de cada `files[]` (lendo `stored_as` quando houver).
3. Pegar o texto de `data/pack.json` e passar INTEIRO pro
   `importar_pack_valor` atual — ele NÃO muda (mesmas chaves PT/EN, mesmo
   filtro A+A, mesmo backup).
4. Copiar cada `assets/*` pra `projects/default/<mesmo path>` (só abaixo de
   `assets/`, barrar `..`; repetida vira cópia em cada path).
5. Asset faltando = aviso na lista (nunca erro); mostrar contagens do
   manifest + "sem imagens" quando `assets == 0`.

## 12.6 Responsabilidades

- Systems/Data: donos do formato `.astralis`, serialização, manifest, hashes, compat.
- Runtime: DataLoader binário, verificação, chave ofuscada, mensagens de erro, import Android.
- Editor: tela Exportar (plataforma + aberto/protegido), geração de chave, empacotamento zip, cache de players.
- QA: testes de matriz player x fita, tamper (hash quebrado deve falhar), retrocompat.
- Lead: aprova mudança de formato (nova versão + migração documentada).

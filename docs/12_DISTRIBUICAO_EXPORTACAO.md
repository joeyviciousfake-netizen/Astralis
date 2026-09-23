# 12 — DISTRIBUIÇÃO E EXPORTAÇÃO PROTEGIDA

VERSION: 1.3 (novo)
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

## 12.6 Responsabilidades

- Systems/Data: donos do formato `.astralis`, serialização, manifest, hashes, compat.
- Runtime: DataLoader binário, verificação, chave ofuscada, mensagens de erro, import Android.
- Editor: tela Exportar (plataforma + aberto/protegido), geração de chave, empacotamento zip, cache de players.
- QA: testes de matriz player x fita, tamper (hash quebrado deve falhar), retrocompat.
- Lead: aprova mudança de formato (nova versão + migração documentada).

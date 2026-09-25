# astralis-studio/ — Astralis Studio (Editor de Cartas e Duelos)

Dono: Editor Engineer. Ver `docs/09_STUDIO_EDITOR.md`, `docs/14_EXPERIENCIA_USUARIO.md`.

Stack (igual ao FM-Studio): Rust + Tauri 2 + **SvelteKit + Svelte 5 (runes)
+ Tailwind 4 + TypeScript**. App de verdade em `src-tauri/` + frontend em `src/`.
Precisa de **Rust 1.77 ou mais novo** (o mesmo mínimo do `Cargo.toml`) e de
`cargo-tauri`. O `app.bat` acha o Rust sozinho: primeiro no PATH, depois na
variável `CARGO_BIN`, depois em `~/.cargo/bin` — se não achar, avisa o que
instalar. No terminal, use `cargo tauri ...` (ou o caminho completo do
`cargo-tauri` na sua máquina).

## Como rodar

Duplo clique em **`astralis-studio/app.bat`** e escolha:

- `[1] Abrir app sem build` — modo dev (`cargo tauri dev`, janela 1400x900).
- `[2] Criar build` — (`cargo tauri build`, o exe sai em `src-tauri/target/release/astralis-studio.exe`).

Sem o menu, no terminal:

```bash
cd astralis-studio
npm install
cargo tauri dev      # app sem build
cargo tauri build    # exe em src-tauri/target/release/
```

O `Jogar` (verde, no topo) precisa do **Godot**: o backend procura
`GODOT_PATH` (variável de ambiente), depois `Godot/Godot_v4.7.2-stable_win64.exe`,
depois qualquer `Godot_v*_win64*.exe` na pasta `Godot/` (versão mais nova
primeiro). Não achou? A mensagem diz onde ele procurou e o que fazer.

Só o frontend no navegador (sem Jogar): `ver-editor.bat` ou `npm run dev`
em http://localhost:1420. `npm run build` confere o build estático (gera `build/`).

## Telas (dado Astralis, visual em pílulas Simples/Avançado)

- **Cartas** (`CardStudio.svelte`): lista virtualizada + busca + filtros, detalhe
  em caixas com ↺, prévia (cinza automático sem arte), Salvar/Validar/Duplicar/
  Criar nova/▶ Jogar. Arte via arrastar PNG.
  Campos FM (só dado, o jogo ignora na mesa): estrelas guardiãs 1/2, senha,
  starchips, tipos Equipamento/Ritual + 6 tipos de monstro novos; sem arte ou
  sem texto mostra aviso (comum no pack FM).
- **Duelistas** (`DuelistsStudio.svelte`): Simples (nome, retrato PNG, deck
  select, vida + arquétipo Bravo/Equilibrado/Defensor num clique) / Avançado
  (3 sliders + dificuldade + arena/música). Salvar/Validar/Duplicar/Criar/▶ Jogar
  (pula para o Duelo com ele escolhido).
- **Decks** (`DecksStudio.svelte`): busca + clique/duplo clique adiciona, lista
  com ✕, contador x/40 + aviso, Validar (20..60? IDs existem?)/Salvar/Duplicar.
- **Fusões** (`FusionsStudio.svelte`): Simples (receitas A+B=C + Testar = só
  confere o dado, sem jogar) / Avançado (regras tipo+atributo→resultado +
  prioridade). Salva `fusions.json` preservando o formato.
- **Efeitos** (`EffectsStudio.svelte`): galeria dos modelos + builder visual
  trigger→condições→alvo→ações com texto derivado. SEM Testar/Play (motor não
  existe no runtime — aviso fixo "execução vem depois").
- **Duelo** (`DuelStudio.svelte`): 2 duelistas + vida (sugere a do duelista 1)
  + ▶ Jogar; Avançado (seed, arena, ordem). Monta o setup na hora num arquivo
  temporário do SO (um por duelo) e abre o Godot com `--project` + `--setup`
  por cima. O jogo é 100% controle (D19/D26): no Studio é só clicar em Jogar,
  dentro do jogo quem joga é o controle.
- **Cenas** (`ScenesStudio.svelte`): lista + editor de falas (personagem, texto,
  fundo) com prévia de leitura, salvando em `projects/default/scenes/`. Sem
  grafo/timeline e sem Play (formato ainda não lido pelo Astralis).
- **Exportar** (`ExportStudio.svelte`): plataforma + Aberto/Protegido +
  checklist "testou?" + Exportar. A caixa mostrada é
  `Astralis-windows.zip` / `Astralis-linux.zip` / `Astralis-android.zip`, mas
  **nada é empacotado ainda**: o botão só valida o projeto inteiro e avisa que
  o empacotamento `.astralis`+zip vem depois (sem fingir).
## Projeto do editor (boot vazio)

O Studio abre VAZIO: nada carregado, só mostra o que você importar. Todo o
dado mora em `astralis-studio/projects/default/` (criado vazio: `cards/`,
`duelists/`, `decks/`, `arenas/`, `scenes/`, `assets/`, `fusions.json` e
`effects.json` vazios válidos). `schemas/examples/` é o jogo embutido — o
editor nunca lê nem escreve lá.

- **Importar** (botão 📥 ao lado do Exportar + seção no topo da aba Exportar):
  escolhe um `.json` pack, valida contra os schemas (cartas/duelistas/decks/
  fusões + refs, erros em PT-BR), mostra "X cartas, Y duelistas, Z decks,
  W fusões substituídos" e SUBSTITUI o projeto (arquivos em
  `projects/default/...`, `fusions.json` trocado inteiro, backup automático
  em `projects/default/backups/pack_<data>_<hora>/`). Equips do pack são
  ignorados com aviso (sem schema V1, o jogo ignora). No navegador é só
  leitura — importar precisa do app via `app.bat`.
- **Validação** (`ValidationPanel.svelte`): relatório por carta, selo clicável.

## Artes (arrastar PNG)

Arrastar um PNG para carta/duelista/cena importa via comando `importar_asset`:
valida PNG ≤ 5 MB, copia para
`projects/default/assets/<cards|portraits|backgrounds>/` e referencia no dado
(relativo à pasta do projeto, que o jogo lê via `--project`). Sem arte, a
tela mostra placeholder cinza automático.
No navegador (sem app) dá só para ver — importar precisa do app via `app.bat`.

## Formato da cena simples (aba Cenas, `projects/default/scenes/<id>.json`)

```json
{
  "schema_version": 1,
  "id": "scene_encontro_rival",
  "name": "Encontro com o Rival",
  "background": "assets/backgrounds/campo.png",
  "lines": [
    { "character": "Rival", "text": "Vamos duelar!" },
    { "character": "Hero", "text": "Pode vir!", "background": "assets/backgrounds/campo_noite.png" }
  ]
}
```

Regras: `id` snake_case (vira o nome do arquivo), `name` como aparece na
lista, `background` é o fundo padrão (PNG em
`projects/default/assets/backgrounds/`), `lines` precisa de pelo menos 1 fala com `character` + `text` (fundo por fala
é opcional e troca só naquela fala). Sem grafo/timeline agora (vêm depois);
schema formal fica p/ depois. Sem Play de cena: o Astralis ainda não lê esse
formato (R4 — sem fingir execução).

## Onde salva

**Salvar** escreve de volta nos dados de trabalho (no app via comandos Rust;
no navegador tudo é somente-leitura — salvar/validar/jogar/importar precisam
do app):

```text
cartas     -> projects/default/cards/<id>.json      (salvar_carta, valida antes)
duelistas  -> projects/default/duelists/<id>.json   (salvar_duelista)
decks      -> projects/default/decks/<id>.json      (salvar_deck)
fusões     -> projects/default/fusions.json         (salvar_fusoes, inteiro)
efeitos    -> projects/default/effects.json         (salvar_efeitos, inteiro)
duelo      -> temporário do SO                      (jogar_duelo, --setup por cima)
cenas      -> projects/default/scenes/<id>.json     (salvar_cena)
artes      -> projects/default/assets/<cards|portraits|backgrounds>/ (importar_asset)
```

Só edita **dado** (R1/R3). Validação espelha `schemas/card.schema.json`; efeitos
só dos modelos de `projects/default/effects.json` (R4: só o que o Astralis sabe
executar). `salvar_carta` é igual aos outros `salvar_*`: carta inválida **não**
vai para o disco (`Arruma antes de salvar:\n- …`).

Regra do efeito, com os três estados (o gate antigo era "fail-open" e deixava
passar qualquer id inventado depois do boot):

| Projeto | Carta cita efeito | Resultado |
| --- | --- | --- |
| sem `effects.json` / lista vazia | id qualquer | **AVISO**: a carta não pode citar efeito até você cadastrar um modelo (aba Efeitos) |
| com efeitos | id cadastrado | passa |
| com efeitos | id fora da lista | **ERRO** com o nome do efeito e onde corrigir |

## Como o Jogar chama o Astralis

Preview unificado (doc 10): salva o dado e lança o Astralis de verdade com o
projeto do editor — o editor nunca calcula jogo (R1/R4), só prepara dado +
abre o jogo:

```text
jogar_carta -> valida tudo -> salva <id>.json -> abrir_processo(Godot, --path astralis -- --project "<projects/default>")
jogar_duelo -> valida refs  -> grava setup em <temp>\duel_studio_rapido_<pid>_<seg>_<n>.json
                                 -> abrir_processo(Godot, --path astralis -- --project "<projects/default>" --setup <temp>)
```

O jogo lê TUDO da pasta do `--project` e põe o `--setup` por cima (só no
duelo). Contexto mínimo V1, sem seed na carta (seed fixa 42 no duelo).
O arquivo do setup tem nome por invocação (dois dueles no mesmo segundo não se
atropelam) e os antigos (>1 h) são apagados no duelo seguinte.

O alvo primário do lançamento é o Windows: lá ele usa `cmd /C start` para abrir
uma janela normal, solta do Studio. O Rust usa `std::process::Command`
diretamente — o `tauri-plugin-shell` está registrado, mas o frontend não o
importa e o Rust não depende dele para nada.

Comandos Rust em `src-tauri/src/main.rs` (+ testes `cargo test`): cartas
(listar/salvar/validar/jogar), duelistas (listar/salvar/validar + `ler_deck`
leitura), decks (listar/salvar/validar), fusões (ler/salvar/testar = só dado),
efeitos (ler/salvar/validar, sem executar), duelo (listar_arenas/jogar_duelo),
cenas (listar/salvar/validar), assets (importar_asset), exportar
(validar_projeto), boot vazio (preparar_boot) e diagnóstico de IPC
(`debug_push_batch`, que guarda as últimas 500 linhas em memória). Erros
sempre em PT-BR dizendo onde clicar.

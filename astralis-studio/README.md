# astralis-studio/ — Astralis Studio (Editor de Cartas e Duelos)

Dono: Editor Engineer. Ver `docs/09_STUDIO_EDITOR.md`, `docs/14_EXPERIENCIA_USUARIO.md`.

Stack (igual ao FM-Studio): Rust + Tauri 2 + **SvelteKit + Svelte 5 (runes)
+ Tailwind 4 + TypeScript**. App de verdade em `src-tauri/` + frontend em `src/`.
Rust 1.98 + `cargo-tauri` ficam em `C:\Users\Max\.cargo\bin` (fora do PATH) —
o `app.bat` ajusta o PATH sozinho; no terminal chame pelo caminho completo.

## Como rodar

Duplo clique em **`astralis-studio/app.bat`** e escolha:

- `[1] Abrir app sem build` — modo dev (`cargo tauri dev`, janela 1400x900).
- `[2] Criar build` — (`cargo tauri build`, o exe sai em `src-tauri/target/release/astralis-studio.exe`).

Sem o menu, no terminal:

```bash
cd astralis-studio
npm install
C:\Users\Max\.cargo\bin\cargo-tauri tauri dev    # app sem build
C:\Users\Max\.cargo\bin\cargo-tauri tauri build  # exe em src-tauri/target/release/
```

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
  + ▶ Jogar; Avançado (seed, arena, ordem). Salva `duel_setup.json` temporário
  e abre o Godot com ele.
- **Cenas** (`ScenesStudio.svelte`): lista + editor de falas (personagem, texto,
  fundo) com prévia de leitura, salvando em `campaign/scenes/`. Sem
  grafo/timeline e sem Play (formato ainda não lido pelo Astralis).
- **Exportar** (`ExportStudio.svelte`): plataforma + Aberto/Protegido +
  checklist "testou?" + Exportar (só valida o projeto e avisa que o
  empacotamento `.astralis`+zip vem depois — sem fingir).
- **Importar** (botão 📥 ao lado do Exportar + seção no topo da aba Exportar):
  escolhe um `.json` pack, valida contra os schemas (cartas/duelistas/decks/
  fusões + refs, erros em PT-BR), mostra "X cartas, Y duelistas, Z decks,
  W fusões importados" e incorpora ao projeto (arquivos em
  `schemas/examples/...` + merge em `fusions.json` sem duplicar, com `.bak`
  antes). Equips do pack são ignorados com aviso (sem schema V1, o jogo
  ignora). No navegador é só leitura — importar precisa do app via `app.bat`.
- **Validação** (`ValidationPanel.svelte`): relatório por carta, selo clicável.

## Artes (arrastar PNG)

Arrastar um PNG para carta/duelista/cena importa via comando `importar_asset`:
valida PNG ≤ 5 MB, copia para `astralis/assets/<cards|portraits|backgrounds>/`
e referencia no dado. Sem arte, a tela mostra placeholder cinza automático.
No navegador (sem app) dá só para ver — importar precisa do app via `app.bat`.

## Formato da cena simples (aba Cenas, `campaign/scenes/<id>.json`)

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
lista, `background` é o fundo padrão (PNG em `astralis/assets/backgrounds/`),
`lines` precisa de pelo menos 1 fala com `character` + `text` (fundo por fala
é opcional e troca só naquela fala). Sem grafo/timeline agora (vêm depois);
schema formal fica p/ depois. Sem Play de cena: o Astralis ainda não lê esse
formato (R4 — sem fingir execução).

## Onde salva

**Salvar** escreve de volta nos dados de trabalho (no app via comandos Rust;
no navegador tudo é somente-leitura — salvar/validar/jogar/importar precisam
do app):

```text
cartas     -> schemas/examples/cards/<id>.json      (salvar_carta)
duelistas  -> schemas/examples/duelists/<id>.json   (salvar_duelista)
decks      -> schemas/examples/decks/<id>.json      (salvar_deck)
fusões     -> schemas/examples/fusions.json         (salvar_fusoes, inteiro)
efeitos    -> schemas/examples/effects.json         (salvar_efeitos, inteiro)
duelo      -> schemas/examples/duel_setup.json      (jogar_duelo, temporário)
cenas      -> campaign/scenes/<id>.json             (salvar_cena)
artes      -> astralis/assets/<cards|portraits|backgrounds>/ (importar_asset)
```

Só edita **dado** (R1/R3). Validação espelha `schemas/card.schema.json`; efeitos só dos
modelos de `schemas/examples/effects.json` (R4: só o que o Astralis sabe executar).

## Como o Jogar chama o Astralis

Preview unificado (doc 10): salva o dado e lança o Astralis de verdade — o
editor nunca calcula jogo (R1/R4), só prepara dado + abre o jogo:

```text
jogar_carta -> valida tudo -> salva <id>.json -> cmd start Godot --path astralis
jogar_duelo -> valida refs  -> salva duel_setup.json (temporário, o jogo lê
               esse arquivo) -> cmd start Godot --path astralis
```

Comandos Rust em `src-tauri/src/main.rs` (+ 24 testes `cargo test`): cartas
(listar/salvar/validar/jogar), duelistas (listar/salvar/validar + `ler_deck`
leitura), decks (listar/salvar/validar), fusões (ler/salvar/testar = só dado),
efeitos (ler/salvar/validar, sem executar), duelo (listar_arenas/jogar_duelo),
cenas (listar/salvar/validar), assets (importar_asset), exportar
(validar_projeto). Erros sempre em PT-BR dizendo onde clicar. Shell via
`tauri-plugin-shell` + permissão `shell:allow-open`.

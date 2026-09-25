# schemas/ — Contratos de dados (JSON de TRABALHO, não distribuição)

Dono: Systems/Data Engineer. Ver `docs/04_CONTRATO_DADOS.md`, `docs/13_TABULEIRO_DUELO.md`.
Status: V1 — 7 schemas + conteúdo oficial FM importado (`examples/`) + pack de importação (`packs/`).

> R6: estes JSON são formato de TRABALHO (pasta editável). Distribuição é `.astralis` binário trancado (doc 12). Nunca exponha JSON de distribuição em texto.

> O conteúdo oficial FM (D20) é DADO OFICIAL: 722 cartas, 39 duelistas, 39 decks, 25.081 fusões. NÃO se edita, não se regenera, não se " conserta". Se um número parecer errado, ver **Fatos e GAPs** antes de mexer.

## Arquivos

```text
schemas/
  README.md
  card.schema.json         <- 1 carta (doc 05.3)
  duelist.schema.json      <- 1 duelista + ai_preset (doc 05.3/05.4)
  deck.schema.json         <- 1 deck = lista de Card IDs (doc 05.3)
  fusion.schema.json       <- fusions.json: recipes[] + rules[] (doc 06)
  effect.schema.json       <- effects.json: effects[] TRIGGER->...->FLOW (doc 07)
  duel_setup.schema.json   <- 1 setup de duelo (doc 13.7)
  arena.schema.json        <- 1 arena = layout XY dos 20 slots fixos + hand opcional (p0/p1 x/y/step), só desenho (D24)
  packs/                   <- PACKS de importação (fora de examples/, R8)
    fm_original_pack.json  <- FONTE de importação (2,62 MB), gerado por tools/fm_import.py:
                               722 cartas + 39 duelistas + 39 decks + 25.131 receitas + 0 regras
                               + 4.041 pares de equips (SEM schema — GAP 4)
                               (SEM texto/imagem FM no repo, por decisão)
  examples/                <- conteúdo OFICIAL FM (D20), jogável
    arenas/arena_starter.json  <- 20 slots XY (x 780-1536, y 128-789) + hand p0 1240/980/95 e p1 1240/20/60 (D24)
    cards/                 <- 722 cartas fm_0001..fm_0722 (621 monstros, 34 equip, 33 spell, 24 ritual, 10 trap)
    duelists/              <- 39 duelistas fm_duelist_01..39 (starting_lp 8000, ai_preset normal)
    decks/                 <- 39 decks fm_deck_01..39 (40 cartas cada, máx 3 cópias, seed 42)
    fusions.json           <- 25.081 receitas (fm_fusion_00001..fm_fusion_25131) + 0 regras genéricas
    effects.json           <- effect_dano_ao_invocar + effect_enfraquecer_inimigo (flow.mode = "sequence")
    duel_setup.json        <- duel_fm_abertura (8000 LP, first_p1, seed 42, arena_starter)
  starter_backup/          <- conteúdo custom de TESTE. NUNCA é o projeto do editor (D20/D29)
    cards/ (40 card_*)  duelists/ (duelist_hero + duelist_rival)  decks/ (2)
    fusions_starter_3.json (2 receitas + 1 regra)  duel_setup_starter_4000.json (4000 LP)
    fusions_merged_25083.bak  <- arquivo órfão, ver GAP 8
```

## O que tem dentro hoje (contagem verificada)

| Onde | O quê | Quantidade | IDs / observação |
|---|---|---|---|
| `examples/cards/` | cartas FM | **722** | `fm_0001`..`fm_0722` (621 monster, 34 equip, 33 spell, 24 ritual, 10 trap) |
| `examples/duelists/` | duelistas FM | **39** | `fm_duelist_01`..`fm_duelist_39` (LP 8000 = D20) |
| `examples/decks/` | decks FM | **39** | `fm_deck_01`..`fm_deck_39`, **40 cartas cada** |
| `examples/fusions.json` | receitas FM | **25.081** | `fm_fusion_00001`..`fm_fusion_25131` (50 buracos — GAP 1) |
| `examples/fusions.json` | regras genéricas | **0** | o fallback por regra (D08) existe no código, o dado FM não usa (GAP 2) |
| `examples/effects.json` | efeitos | **2** | `effect_dano_ao_invocar`, `effect_enfraquecer_inimigo` |
| `examples/duel_setup.json` | setups | **1** | `duel_fm_abertura`, 8000 LP, seed 42 |
| `examples/arenas/` | arenas | **1** | `arena_starter` (20 slots + mão p0/p1) |
| `packs/fm_original_pack.json` | pack de importação | 2,62 MB | 722 / 39 / 39 / 25.131 receitas / 4.041 equips |
| `starter_backup/` | custom de teste | 40 / 2 / 2 / 3 | só teste; o projeto do editor é `astralis-studio/projects/default/` (D29) |

## Regras de validação V1

1. `schema_version == 1` em TODO arquivo (contrato, exemplos e dados).
2. IDs estáveis `snake_case` (`^[a-z][a-z0-9_]*$`); nome exibido pode mudar, ID nunca.
3. Toda ref existe: `deck.cards[]` → Card IDs; `duelist.deck_id` → Deck; `duel_setup.duelist_id/deck_id` → Duelista/Deck; `duel_setup.arena_id`/`duelist.arena` → Arena (D24); `fusion input/result` → Card IDs; `card.effects[]` → Effect IDs.
4. Vida (LP — regra de precedência D34): `duel_setup.starting_lp` é OBRIGATÓRIO (**1 a 99999**) e sempre vence na batalha (runtime lê de lá); `duelist.starting_lp` é OPCIONAL (1–99999), só sugestão que pré-preenche o Duelo rápido no Studio (ausente = 4000). `turn_order in [first_p1, first_p2, random]`; `seed` inteiro; `win` com os 2 booleans.
   - Teto 99999: mesmo limite que o Studio já aplica ao montar o duelo (`astralis-studio/src-tauri/src/main.rs:1303` recusa vida ≤ 0 ou > 99999). O schema passou a declarar o que o editor já recusa — aperto compatível, dado real (4000 e 8000) não muda.
5. Carta: `attack` e `defense` em **0 a 9999**.
   - É o mesmo teto do runtime (`astralis/duel/summon_system.gd:60-61` e `fusion_system.gd:248-249` usam `clampi(...,0,9999)`, `battle_system.gd:70/85` idem) e do Studio (`main.rs:427/435` recusa fora de `0..=9999`). Antes o schema era o único lugar sem teto. Dado FM real: ATK máx 4500, DEF máx 3800 → nada foi invalidado.
6. Deck com 20–60 cartas (mínimo tutorial 20; construído 40–60; decks FM D20 com 40; máximo 60 = zona deck doc 13.1).
7. `ai_preset`: `dificuldade in [facil, normal, dificil]`, 3 params 0–100.
8. Fusão: receita exata vence regra; regra precisa `priority` + ≥1 critério em `when`. Receitas `A+A` (mesma carta nos dois lados) **são dado válido no schema mas nunca disparam no jogo** — o Importar do Studio filtra com aviso (GAP 1).
9. Efeito: `trigger/action` só do vocabulário MVP; `target` compatível com a action. `flow.mode`, quando presente, só aceita `"sequence"` — o único motor existente é o seqüencial (Studio `main.rs:1199`, doc 07 §7.2). `flow` é OPCIONAL; se faltar, o efeito é válido (roda a lista de actions em ordem).
10. Arena (D24): `schema_version == 1`; `id` snake_case; `slots` com exatos 20 itens, `slot_id` único no padrão `^(p0|p1)_(m|s)[0-4]$` (p0 = você/baixo = duelist1, p1 = rival/cima = duelist2; m = monstro, s = magia); `x` **0-1920** e `y` **0-1080** (resolução fixa 1920x1080 por D16 — o `hand` já tinha esses limites, os `slots` eram a inconsistência); `background/description` opcionais; `hand` opcional (se ausente, arena antiga continua válida e runtime usa fallback): `hand.p0` = sua mão/baixo, `hand.p1` = mão do rival/cima (desenha de costas); cada um com `x` 0-1920, `y` 0-1080, `step` 40-200 (distância entre cartas); `arena_starter` usa `p0 1240/980/95` (centro sob o campo 780-1701) e `p1 1240/20/60` (topo); só desenho, nunca regra.
11. R3 DATA != LOGIC: nenhum dado contém `script/code/function/eval/lambda/callback`. Proibido campo de lógica; validação extra: `additionalProperties: false` nos schemas.
12. Mudança incompatível = nova versão + migração documentada. Nunca mudar silenciosamente.
13. Extensão FM (COMPATÍVEL, `schema_version` continua 1 — só enums + opcionais, as 722 atuais continuam válidas):
     - `card_type`: `monster | spell | trap | equip | ritual`. Magic FM vira `spell` (NUNCA renomear `spell` p/ `magic`); `equip` = equipamento FM; `ritual` = magia de ritual FM (na fonte é categoria não-monstro, sem ATK/DEF).
     - `monster_type` += `beast-warrior | winged-beast | dinosaur | reptile | sea-serpent | fish` (`thunder` já existia, sem mudança). `fish` não estava no pedido e foi incluído p/ não deixar 17 cartas órfãs. Mapeamento FM: minúsculo + espaço→hífen (`Winged Beast`→`winged-beast`).
     - Opcionais: `guardian_star_1/2` (10 estrelas FM minúsculas: sun moon mars jupiter mercury venus saturn uranus neptune pluto), `password` (string `^[0-9]{8}$`, preserva zero à esquerda; ausente = N/A na fonte), `starchip_cost` (int ≥ 0, 999999 = não comprável; ausente = N/A).
     - Monstro continua exigindo `monster_type + attribute + level(1-12) + attack(0-9999) + defense(0-9999)`; não-monstro (`spell/trap/equip/ritual`) não exige nenhum dos 5.
     - Mínimo válido: `{"schema_version":1,"id":"fm_equip_teste","name":"Espada Teste","card_type":"equip"}` (description/artwork/effects/tags opcionais na prática do pack vão preenchidos). Inválidos (reprovados no `--check`): `card_type:"magic"` (usar `spell`), monstro sem os 5 campos, `password:"123"`, `guardian_star_1:"terra"`, `level:13`. **Novos (esta sessão):** `attack:10000`, `defense:10000`.

### Como validar agora

| Comando | O que cobre | Observação |
|---|---|---|
| `python tools/fm_import.py --check` | `card.schema.json` + `deck.schema.json` contra as 722 de `examples/cards/` e o pack inteiro | **único validador automático do repo** (GAP 3). Sai com `rc=0` e `CHECK OK`. O espelho do card dentro do script ainda só checa `>= 0` em ATK/DEF (limite do `--check` = código do QA, não o schema). |
| runtime `astralis/core/runtime_validator.gd` | `schema_version==1`, refs (deck→cartas, duel_setup→duelistas/decks, fusão→cartas) e `starting_lp>0` | Não é validação de schema: não checa arena, nem a estrutura de efeito/fusão. |

## Fatos e GAPs

1. **25.081 (examples) vs 25.131 (pack) — INTENTIONAL E RASTREÁVEL.** A diferença são as **50 receitas `A+A`** (mesma carta nos dois lados). Elas existem na fonte FM, são dado válido no schema, mas **nunca disparam no jogo** (uma fusão exige duas cartas diferentes). O Importar do Studio filtra essas 50 com o aviso "fusões com A e B iguais ignoradas… esse dado nunca dispara" (`astralis-studio/src-tauri/src/main.rs:2087`). Por isso os ids de `examples/fusions.json` vão de `fm_fusion_00001` a `fm_fusion_25131` com **50 buracos** — a numeração vem do pack. **NÃO regenere os arquivos para "fechar" a sequência**: a partir de D20 o conteúdo FM é dado oficial; o número 25.081 é o número certo.
2. **`examples/fusions.json` tem 0 regras genéricas — não é bug.** O caminho de fallback por regra (D08: `tipo+atributo+min_atk` com `priority`) está implementado e testado no runtime (`astralis/duel/fusion_system.gd`) e no Studio, mas o dado FM oficial é 100% receita explícita, então a camada de regra fica sem dado no default. Ela existe para conteúdo novo, não para o FM.
3. **Só 2 dos 7 schemas têm validador automático.** `card.schema.json` e `deck.schema.json` são cobertos por `tools/fm_import.py --check`. `arena.schema.json`, `duel_setup.schema.json`, `effect.schema.json` e `fusion.schema.json` **não são validados por nada em lugar nenhum do repo** — nem pelo `--check`, nem pelo `runtime_validator.gd`, nem pelo Studio (que valida LP e `flow.mode` no seu próprio código Rust, não pelo schema). Consequência: um `arena.json` com x/y fora da tela só é pego na hora de desenhar.
4. **`project.json`, `runtime_version` e `author_id` não existem em nenhum schema.** Documentados em `docs/04_CONTRATO_DADOS.md` §4.3 e `docs/12_DISTRIBUICAO_EXPORTACAO.md` §12.2, mas não há schema de projeto no `schemas/` nem campo correspondente em nenhum dos 7. Todo o versionamento do doc 12 está hoje inexistente no contrato.
5. **`duelist.arena` existe no schema mas o runtime nunca lê.** O campo está declarado em `duelist.schema.json`; quem decide a arena é `duel_setup.arena_id`. O duelista só é sugestão. Não calcule vantagem nem derive arena do duelista (R1).
6. **24 cartas `ritual` e 34 cartas `equip` existem no dado mas não têm regra na mesa.** O contrato aceita (D21), o editor mostra como tipo, mas o runtime V1 não executa ritual nem equipar: o campo `equips` do pack (4.041 pares) também não tem schema e é ignorado. Dado aceito e sem efeito — nunca invente a regra no editor.
7. **A arte e a descrição das 722 cartas FM estão vazias.** `description: ""` e `artwork: "assets/fm/card_XXXX.png"` apontando para arquivo inexistente (decisão: texto e imagem FM não entram no repo). O dado é **estrutural, não visual**. O editor deve mostrar placeholder + aviso, nunca fingir que o asset existe.
8. **Linha órfã que pode darruit:** `schemas/starter_backup/fusions_merged_25083.bak` (25.083) convive com `examples/fusions.json` (25.081). São duas fontes de número diferentes e o `.bak` é resíduo de teste. Se alguém "consertar" o 25.081 para 25.083, quebra o dado oficial. O número válido é **25.081** (pack 25.131 − 50 `A+A`).

## Impacto

- Runtime (astralis/): carrega estes arquivos; preview/test usam os mesmos dados (R1/R2). Nenhuma mudança nesta sessão afeta o runtime: os limites novos só passam a valer onde o JSON é validado contra o schema. Arena é só layout: lógica usa ID fixo, desenho usa x/y com fallback p/ grade padrão (D24). Mão é só layout: se `hand` faltar, runtime usa fallback (p0 embaixo, p1 em cima); `p1` sempre desenha de costas. Campos FM novos (`guardian_star_*`, `password`, `starchip_cost`, `equip`, `ritual`) são DADO aceito e ignorado na mesa V1 — sem regra nova, sem Fake (R1/R4 ok).
- Editor (Studio): o Studio já exigia 0..9999 em ATK/DEF (`main.rs:427/435`), `sequence` em flow (`main.rs:1199`) e ≤ 99999 em vida (`main.rs:1303`). Os schemas passaram a dizer o mesmo — **nada muda para o editor, que agora está alinhado ao contrato**. Ele **não** valida x/y de slot: um slot fora de 1920x1080 passa no editor e no schema, e só aparece errado na mesa.
- Compatibilidade: os 4 apertos são **compatíveis** (só added bounds/enum já existente) — `schema_version` continua **1**, nenhuma mudança de `required`, nenhum enum existente alterado, nenhum arquivo de dado tocado (doc 04.3).

## GAPs p/ o editor (o que a carta FM tem e o Studio não mostra)

1. `guardian_star_1/2`: contrato aceita, Studio não tem campo (D33 travou "sem campo de outro jogo"). Mostrar como leitura (2 selos) ou esconder; NUNCA calcular vantagem de estrela (R1).
2. `password` / `starchip_cost`: contrato aceita, Studio não mostra. Sugestão: campo leitura no detalhe da carta.
3. `description` vazia nas 722 + `artwork` apontando p/ `assets/fm/card_XXXX.png` SEM arquivo no repo (proposital: texto/imagem FM não entram no repo). Studio deve mostrar placeholder cinza + aviso "sem arte/texto", igual ao Assets atual.
4. `equips[4041 pares]`: sem schema próprio (formato provisório `{equip, monster}` c/ refs p/ carta, fora do contrato V1 — runtime ignora, R4; ação `equip` é futuro no doc 07). Schema formal quando o runtime suportar equipar.
5. `ritual` como tipo não-monstro: Studio hoje só conhece monster/spell/trap — precisa do 4º/5º selo (`equip`, `ritual`) na lista/filtro.
6. `fish` + `beast-warrior`/`winged-beast`/`dinosaur`/`reptile`/`sea-serpent` (+5 tipos FM): filtro de tipo do Studio precisa dos 6 novos valores (o enum do schema já tem os 19).

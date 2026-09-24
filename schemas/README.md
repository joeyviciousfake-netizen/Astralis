# schemas/ — Contratos de dados (JSON de TRABALHO, não distribuição)

Dono: Systems/Data Engineer. Ver `docs/04_CONTRATO_DADOS.md`, `docs/13_TABULEIRO_DUELO.md`.
Status: V1 CRIADO — 7 schemas + Starter Kit jogável em `examples/`.

> R6: estes JSON são formato de TRABALHO (pasta editável). Distribuição é `.astralis` binário trancado (doc 12). Nunca exponha JSON de distribuição em texto.

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
    fm_original_pack.json  <- FM Original: 722 cartas + 39 duelistas + 39 decks + 25.131 fusões + 4.041 equips (gerado por tools/fm_import.py; SEM texto/imagem FM no repo)
  examples/                <- Starter Kit jogável (doc 09.3)
    arenas/                  <- arena_starter (20 XY copiados do duel_board.gd + hand p0 1240/980/95 e p1 1240/20/60, D24)
    cards/                 <- 40 cartas (38 monstros + 2 magias, D20)
    duelists/              <- duelist_hero (facil) + duelist_rival (normal)
    decks/                 <- deck_starter_hero + deck_starter_rival (40 cartas cada, D17)
    fusions.json           <- 2 receitas + 1 regra fallback
    effects.json           <- effect_dano_ao_invocar + effect_enfraquecer_inimigo
    duel_setup.json        <- duel_starter_4000 (4000 LP, first_p1, seed 42)
```

## Regras de validação V1

1. `schema_version == 1` em TODO arquivo (contrato, exemplos e dados).
2. IDs estáveis `snake_case` (`^[a-z][a-z0-9_]*$`); nome exibido pode mudar, ID nunca.
3. Toda ref existe: `deck.cards[]` → Card IDs; `duelist.deck_id` → Deck; `duel_setup.duelist_id/deck_id` → Duelista/Deck; `duel_setup.arena_id`/`duelist.arena` → Arena (D24); `fusion input/result` → Card IDs; `card.effects[]` → Effect IDs.
4. Vida (LP — regra de precedência D34): `duel_setup.starting_lp` é OBRIGATÓRIO (>0) e sempre vence na batalha (runtime lê de lá); `duelist.starting_lp` é OPCIONAL (1–99999), só sugestão que pré-preenche o Duelo rápido no Studio (ausente = 4000). `turn_order in [first_p1, first_p2, random]`; `seed` inteiro; `win` com os 2 booleans.
4b. Arena (D24): `schema_version == 1`; `id` snake_case; `slots` com exatos 20 itens, `slot_id` único no padrão `^(p0|p1)_(m|s)[0-4]$` (p0 = você/baixo = duelist1, p1 = rival/cima = duelist2; m = monstro, s = magia); `x/y` números em 1920x1080; `background/description` opcionais; `hand` opcional (se ausente, arena antiga continua válida e runtime usa fallback): `hand.p0` = sua mão/baixo, `hand.p1` = mão do rival/cima (desenha de costas); cada um com `x` 0-1920, `y` 0-1080, `step` 40-200 (distância entre cartas); starter usa `p0 1240/980/95` (centro sob o campo 780-1701) e `p1 1240/20/60` (topo); só desenho, nunca regra.
5. Deck com 20–60 cartas (mínimo tutorial 20; construído 40–60; starters D17 com 40; máximo 60 = zona deck doc 13.1).
6. `ai_preset`: `dificuldade in [facil, normal, dificil]`, 3 params 0–100.
7. Fusão: receita exata vence regra; regra precisa `priority` + ≥1 critério em `when`.
8. Efeito: `trigger/action` só do vocabulário MVP; `target` compatível com a action.
9. R3 DATA != LOGIC: nenhum dado contém `script/code/function/eval/lambda/callback`. Proibido campo de lógica; validação extra: `additionalProperties: false` nos schemas.
10. Mudança incompatível = nova versão + migração documentada. Nunca mudar silenciosamente.
11. Extensão FM (COMPATÍVEL, `schema_version` continua 1 — só enums + opcionais, as 40 atuais continuam válidas):
    - `card_type`: `monster | spell | trap | equip | ritual`. Magic FM vira `spell` (NUNCA renomear `spell` p/ `magic`); `equip` = equipamento FM; `ritual` = magia de ritual FM (na fonte é categoria não-monstro, sem ATK/DEF).
    - `monster_type` += `beast-warrior | winged-beast | dinosaur | reptile | sea-serpent | fish` (`thunder` já existia, sem mudança). `fish` não estava no pedido e foi incluído p/ não deixar 17 cartas órfãs. Mapeamento FM: minúsculo + espaço→hífen (`Winged Beast`→`winged-beast`).
    - Opcionais: `guardian_star_1/2` (10 estrelas FM minúsculas: sun moon mars jupiter mercury venus saturn uranus neptune pluto), `password` (string `^[0-9]{8}$`, preserva zero à esquerda; ausente = N/A na fonte), `starchip_cost` (int ≥ 0, 999999 = não comprável; ausente = N/A).
    - Monstro continua exigindo `monster_type + attribute + level(1-12) + attack + defense`; não-monstro (`spell/trap/equip/ritual`) não exige nenhum dos 5.
    - Mínimo válido: `{"schema_version":1,"id":"fm_equip_teste","name":"Espada Teste","card_type":"equip"}` (description/artwork/effects/tags opcionais na prática do pack vão preenchidos). Inválidos (reprovados no `--check`): `card_type:"magic"` (usar `spell`), monstro sem os 5 campos, `password:"123"`, `guardian_star_1:"terra"`, `level:13`.

## Impacto

- Runtime (astralis/): valida e carrega estes arquivos; preview/test usam os mesmos dados (R1/R2). Arena é só layout: lógica usa ID fixo, desenho usa x/y com fallback p/ grade padrão (D24). Mão é só layout: se `hand` faltar, runtime usa fallback (p0 embaixo, p1 em cima); `p1` sempre desenha de costas. Campos FM novos (`guardian_star_*`, `password`, `starchip_cost`, `equip`, `ritual`) são DADO aceito e ignorado na mesa V1 — sem regra nova, sem Fake (R1/R4 ok).
- Editor (Studio): expõe só o que estes schemas + runtime suportam (R4); Starter Kit = New Project. Editor futuro pode mover x/y sem quebrar lógica. Ver GAPS abaixo p/ o que o editor ainda não mostra.

## GAPS p/ o editor (o que a carta FM tem e o Studio não mostra)

1. `guardian_star_1/2`: contrato aceita, Studio não tem campo (D33 travou "sem campo de outro jogo"). Mostrar como leitura (2 selos) ou esconder; NUNCA calcular vantagem de estrela (R1).
2. `password` / `starchip_cost`: contrato aceita, Studio não mostra. Sugestão: campo leitura no detalhe da carta.
3. `description` vazia nas 722 + `artwork` apontando p/ `assets/fm/card_XXXX.png` SEM arquivo no repo (proposital: texto/imagem FM não entram no repo). Studio deve mostrar placeholder cinza + aviso "sem arte/texto", igual ao Assets atual.
4. `equips[4041 pares]`: sem schema próprio (formato provisório `{equip, monster}` c/ refs p/ carta, fora do contrato V1 — runtime ignora, R4; ação `equip` é futuro no doc 07). Schema formal quando o runtime suportar equipar.
5. `ritual` como tipo não-monstro: Studio hoje só conhece monster/spell/trap — precisa do 4º/5º selo (`equip`, `ritual`) na lista/filtro.
6. `fish` (+5 tipos FM): filtro de tipo do Studio precisa dos 6 novos valores. Ver GAPS abaixo p/ o que o editor ainda não mostra.

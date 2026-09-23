# schemas/ — Contratos de dados (JSON de TRABALHO, não distribuição)

Dono: Systems/Data Engineer. Ver `docs/04_CONTRATO_DADOS.md`, `docs/13_TABULEIRO_DUELO.md`.
Status: V1 CRIADO — 6 schemas + Starter Kit jogável em `examples/`.

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
  examples/                <- Starter Kit jogável (doc 09.3)
    cards/                 <- 10 cartas (8 monstros + 2 magias)
    duelists/              <- duelist_hero (facil) + duelist_rival (normal)
    decks/                 <- deck_starter_hero + deck_starter_rival (20 cartas cada)
    fusions.json           <- 2 receitas + 1 regra fallback
    effects.json           <- effect_dano_ao_invocar + effect_enfraquecer_inimigo
    duel_setup.json        <- duel_starter_4000 (4000 LP, first_p1, seed 42)
```

## Regras de validação V1

1. `schema_version == 1` em TODO arquivo (contrato, exemplos e dados).
2. IDs estáveis `snake_case` (`^[a-z][a-z0-9_]*$`); nome exibido pode mudar, ID nunca.
3. Toda ref existe: `deck.cards[]` → Card IDs; `duelist.deck_id` → Deck; `duel_setup.duelist_id/deck_id` → Duelista/Deck; `fusion input/result` → Card IDs; `card.effects[]` → Effect IDs.
4. `starting_lp > 0`; `turn_order in [first_p1, first_p2, random]`; `seed` inteiro; `win` com os 2 booleans.
5. Deck com 20–60 cartas (mínimo tutorial 20; construído 40–60; máximo 60 = zona deck doc 13.1).
6. `ai_preset`: `dificuldade in [facil, normal, dificil]`, 3 params 0–100.
7. Fusão: receita exata vence regra; regra precisa `priority` + ≥1 critério em `when`.
8. Efeito: `trigger/action` só do vocabulário MVP; `target` compatível com a action.
9. R3 DATA != LOGIC: nenhum dado contém `script/code/function/eval/lambda/callback`. Proibido campo de lógica; validação extra: `additionalProperties: false` nos schemas.
10. Mudança incompatível = nova versão + migração documentada. Nunca mudar silenciosamente.

## Impacto

- Runtime (astralis/): valida e carrega estes arquivos; preview/test usam os mesmos dados (R1/R2).
- Editor (Studio): expõe só o que estes schemas + runtime suportam (R4); Starter Kit = New Project.

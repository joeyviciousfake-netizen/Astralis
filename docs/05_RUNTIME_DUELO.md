# 05 — RUNTIME E DUELO

ORIGEM: spec v1.1 seções 7, 13, 14, 15, 16, 17, 18, 92

## 5.1 Astralis runtime

Desenvolvido em Godot, distribuído como executável independente. Usuário usa Astralis, não Godot.

Deve: carregar Project Data válido, campanha, duelos, cartas/duelistas/decks, fusões, efeitos, IA, save/load, áudio, UI, modos especiais de dev.

Módulos conceituais (nomes podem mudar, responsabilidades não):

```text
EXISTE (v1.5):
  core:     DataLoader, ProjectLoader, RuntimeValidator, BoardLayout (só desenho)
  duel:     GameState, DuelManager, TurnManager, SummonSystem, BattleSystem,
            DamageSystem, PositionSystem, FusionSystem
  ui:       DuelTable (mesa = orquestrador da sessão + IA), DuelBoard, CardView
  testing:  suíte GUT
NÃO EXISTE AINDA (V1 em atraso, ver docs/11 roadmap):
  core:     SaveSystem, EventBus
  duel:     EffectSystem (dado carregado, nenhum motor), AIController (a IA hoje
            vive no DuelTable, o que é dívida conhecida)
  campaign: CampaignManager, CampaignRunner, SceneRunner, Dialogue/Choice/BattleTransition
  ui:       AudioManager, AssetLoader/ResourceCache
  debug:    DebugConsole, StateInspector
  testing:  TestHarness/Runner/Reporter (o que existe é o GUT)
```

Quem orquestra a partida é o `DuelManager` (dono da instância de estado) e, na tela, o `DuelTable` (que escolhe qual sistema chamar, em que ordem, com que face/posição/estrela). Nenhum sistema de `duel/` chama outro sistema de regra, exceto `TurnManager→DamageSystem` e `BattleSystem→DamageSystem`.

## 5.2 Duelo: regras fixas vs dados editáveis

FIXO (runtime): fluxo de turno, processamento, invocação/batalha estrutural, dano, estados, AI base.
EDITÁVEL (dados): cartas, ATK/DEF/atributos/tipos, decks, duelistas, LP inicial, efeitos, fusões, recompensas, visual.

"Existe LP" = rule. "Começar com 8000" = data. "Existe Fusion" = capability. "A+B=C" = data.

## 5.3 Card / Deck / Duelist

Card (data, sem scripts individuais):
`id, name, description, artwork, card_type, monster_type, attribute, level, attack, defense, effects[], tags[]`
(campos FM opcionais: `guardian_star_1`, `guardian_star_2`, `password`, `starchip_cost`).
O contrato exato está em `schemas/card.schema.json` — o schema manda, não este parágrafo.

Deck (data): `id, name, cards[]` (20-60 ids) referenciando Card IDs.

Duelist (data-driven):
`id, name, portrait, sprite, deck_id, starting_lp (só sugestão), music, arena, dialogue refs, reward config` + `ai_preset` (ver 5.4).

## 5.4 [MELHORIA V1.2] AI por preset

V1.1 dizia: todos usam mesma base. Mantido que IA é runtime-owned, sem custom scripting na V1. Adição:

```text
Duelist.ai_preset:
  dificuldade: facil | normal | dificil
  agressividade: 0-100
  uso_fusao: 0-100
  protecao_lp: 0-100
```

Studio expõe como 3 sliders + dropdown. Runtime interpreta. Dá identidade (ex.: Kaiba agressivo/fusionador, Joey equilibrado) sem código. Futuro: AI profiles/behavior params completos.

> **Estado real em v1.5:** o `ai_preset` está no contrato e o Studio edita, mas o runtime **ainda não lê** os 4 números. A IA atual é fixa em `duel_table.gd` (regra do original: direto com o mais forte, kill com o mais fraco que vence, melhor margem contra ATK virado para cima) e a guardiã ±500 está desligada num hook. Dado pronto, motor pendente.

## 5.5 MVP Runtime

Carregar projeto/cartas/duelistas/decks, iniciar duelo, turn flow, summon/attack/damage, victory/defeat, fusion, effect engine inicial, save/load.

## 5.6 [MELHORIA V1.5] Duelista Simples/Avançado + arquétipos

Studio no Simples mostra só: nome, retrato, deck, vida + 3 arquétipos num clique (`Bravo: agressivo+fusão alta | Equilibrado | Defensor: protege LP`). Cada arquétipo preenche os 4 params do preset (dificuldade, agressividade, uso_fusao, protecao_lp). Avançado libera os sliders + dropdown. Runtime não muda: só interpreta os números. Mesma validação nos dois modos.

# 05 — RUNTIME E DUELO

ORIGEM: spec v1.1 seções 7, 13, 14, 15, 16, 17, 18, 92

## 5.1 Astralis runtime

Desenvolvido em Godot, distribuído como executável independente. Usuário usa Astralis, não Godot.

Deve: carregar Project Data válido, campanha, duelos, cartas/duelistas/decks, fusões, efeitos, IA, save/load, áudio, UI, modos especiais de dev.

Módulos conceituais (nomes podem mudar, responsabilidades não):
`core: GameState, DataLoader, ProjectLoader, SaveSystem, EventBus, RuntimeValidator`
`duel: DuelManager, TurnManager, BattleSystem, SummonSystem, DamageSystem, PositionSystem, FusionSystem, EffectSystem, AIController`
`campaign: CampaignManager, CampaignRunner, SceneRunner, Dialogue/Choice/Transition/BattleTransition`
`ui/assets/debug/testing`: telas fixas, AssetLoader/ResourceCache/AudioManager, DebugConsole/StateInspector, TestHarness/Runner/Reporter.

## 5.2 Duelo: regras fixas vs dados editáveis

FIXO (runtime): fluxo de turno, processamento, invocação/batalha estrutural, dano, estados, AI base.
EDITÁVEL (dados): cartas, ATK/DEF/atributos/tipos, decks, duelistas, LP inicial, efeitos, fusões, recompensas, visual.

"Existe LP" = rule. "Começar com 8000" = data. "Existe Fusion" = capability. "A+B=C" = data.

## 5.3 Card / Deck / Duelist

Card (data, sem scripts individuais):
`id, name, description, artwork, frame/style, card_type, monster_type, attribute, level, attack, defense, effects[], tags[]`

Deck (data): `id, name, cards[]` referenciando Card IDs.

Duelist (data-driven):
`id, name, portrait, sprite, deck_id, starting_lp, music, arena/background, dialogue refs, reward config`

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

## 5.5 MVP Runtime

Carregar projeto/cartas/duelistas/decks, iniciar duelo, turn flow, summon/attack/damage, victory/defeat, fusion, effect engine inicial, save/load.

## 5.6 [MELHORIA V1.5] Duelista Simples/Avançado + arquétipos

Studio no Simples mostra só: nome, retrato, deck, vida + 3 arquétipos num clique (`Bravo: agressivo+fusão alta | Equilibrado | Defensor: protege LP`). Cada arquétipo preenche os 4 params do preset (dificuldade, agressividade, uso_fusao, protecao_lp). Avançado libera os sliders + dropdown. Runtime não muda: só interpreta os números. Mesma validação nos dois modos.

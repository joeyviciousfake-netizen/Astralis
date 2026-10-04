# 05 — RUNTIME E DUELO


## 5.1 Astralis runtime

Desenvolvido em Godot, distribuído como executável independente. O usuário usa
Astralis, não Godot.

Módulos, pelo que cada um é dono de saber:

```text
EXISTE:
  core:     DataLoader, ProjectLoader, RuntimeValidator, BoardLayout (arena),
            card_layout (lê layouts/ do projeto; o default embutido é fallback)
  duel:     GameState, DuelManager, TurnManager, SummonSystem, BattleSystem,
            DamageSystem, PositionSystem, FusionSystem  <- SISTEMAS DE REGRA (R1)
  duel3d:   a TELA do duelo em 9 arquivos, UM ASSUNTO CADA:
            mesa_3d.gd (orquestrador + dono das medidas),
            painel_carta_3d.gd, carta_3d.gd (fábrica),
            entrada_mao_3d.gd, menus_3d.gd, vista_3d.gd, campo_3d.gd,
            cursor_3d.gd, moeda_3d.gd
            -> o mapa com o dono de cada número está no doc 15 §15.7
  ai:       ia_rival.gd (a IA ESCOLHE carta e alvo; a mesa EXECUTA, D68)
  ui:       card_view.gd (a carta 2D pelo molde)
  testing:  a suíte GUT
NÃO EXISTE:
  duel:     EffectSystem (o dado é carregado e validado, não há motor — D30),
            AIController (a IA de hoje é TEMPORÁRIA de propósito, D55)
  core:     SaveSystem, EventBus
  campaign: CampaignManager, CampaignRunner, SceneRunner, Dialogue/Choice
  ui:       AudioManager, AssetLoader/ResourceCache
  debug:    DebugConsole, StateInspector
  testing:  TestHarness/Runner/Reporter (o que existe é o GUT)
```

Quem orquestra a partida é o `DuelManager` (dono da instância de estado) e, na
tela, a `mesa_3d.gd` — que escolhe qual sistema chamar, em que ordem, com que
face/posição/estrela, **pelo mesmo caminho para o jogador e para o rival**
(`_rival_auto`). Nenhum sistema de `duel/` chama outro sistema de regra, exceto
`TurnManager→DamageSystem` e `BattleSystem→DamageSystem`. A tela não decide
regra nenhuma: ela pergunta (`can_attack`, `SummonSystem.construir_instancia`) e
desenha o que o motor devolveu.

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

## 5.4 AI por preset

A IA é **runtime-owned**, sem custom scripting. O preset dá identidade sem
código:

```text
Duelist.ai_preset:
  dificuldade: facil | normal | dificil
  agressividade: 0-100
  uso_fusao: 0-100
  protecao_lp: 0-100
```

O Studio expõe como 3 sliders + dropdown.

> **Estado real:** o `ai_preset` está no contrato e o Studio edita, mas o
> runtime **não lê** os 4 números. A escolha da IA é **temporária** e a escolha
> fina não foi portada (D55); a escolha de hoje mora em
> `astralis/ai/ia_rival.gd` e é só "primeiro monstro da mão" e "primeiro alvo"
> (D68). Ver 5.5.

## 5.5 A IA DO RIVAL HOJE

`astralis/ai/ia_rival.gd` tem **duas decisões e nada mais**:

- `escolher_invocacao()` — o índice do monstro na mão.
- `escolher_ataque()` — o índice do alvo. `target_slot` **menor que zero é ataque
  direto** no jogador (e só é legal com o campo do outro lado vazio), nunca
  "sem alvo".

O rival invoca o primeiro monstro e ataca o primeiro monstro em campo. A mesa é
quem **executa**, pelo mesmo caminho da jogada do jogador. A IA não conduz o
turno, não conhece a tela e não tem método de execução — se tivesse, a regra
estaria morando nela e a R1 estaria quebrada (o GUT trava isso).

Dado pronto, motor pendente. Quando o motor for feito, a escolha mora em
`duel/` (sistema real, testado sem mesa), **nunca dentro de um arquivo de tela**.

## 5.6 Duelista Simples/Avançado + arquétipos

Studio no Simples mostra só: nome, retrato, deck, vida + 3 arquétipos num clique (`Bravo: agressivo+fusão alta | Equilibrado | Defensor: protege LP`). Cada arquétipo preenche os 4 params do preset (dificuldade, agressividade, uso_fusao, protecao_lp). Avançado libera os sliders + dropdown. Runtime não muda: só interpreta os números. Mesma validação nos dois modos.

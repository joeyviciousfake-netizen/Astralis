# 05 — RUNTIME E DUELO

ORIGEM: spec v1.1 seções 7, 13, 14, 15, 16, 17, 18, 92

## 5.1 Astralis runtime

Desenvolvido em Godot, distribuído como executável independente. Usuário usa Astralis, não Godot.

Deve: carregar Project Data válido, campanha, duelos, cartas/duelistas/decks, fusões, efeitos, IA, save/load, áudio, UI, modos especiais de dev.

Módulos conceituais (nomes podem mudar, responsabilidades não):

```text
EXISTE (v2.0):
  core:     DataLoader, ProjectLoader, RuntimeValidator, BoardLayout (só desenho),
            Asset3D (carregador de .glb, só desenho)
  duel:     GameState, DuelManager, TurnManager, SummonSystem, BattleSystem,
            DamageSystem, PositionSystem, FusionSystem  <- SISTEMAS DE REGRA (R1)
  duel3d:   a TELA do duelo em 8 arquivos, UM ASSUNTO CADA (D54-D67):
            mesa_3d.gd (orquestrador + dono das medidas),
            painel_carta_3d.gd, faixa_2d.gd, carta_3d.gd (fábrica),
            menus_3d.gd, vista_3d.gd, campo_3d.gd, cursor_3d.gd
            -> o mapa com o dono de cada número está no doc 15 §15.8
  ai:       ia_rival.gd (a IA ESCOLHE carta e alvo; a mesa EXECUTA, D68)
  ui:       CardView (a carta 2D/molde; a mesa 2D e o DuelTable saíram no D54/D58)
  testing:  suíte GUT
NÃO EXISTE AINDA (V1 em atraso, ver docs/11 roadmap):
  core:     SaveSystem, EventBus
  duel:     EffectSystem (dado carregado, nenhum motor),
            AIController (a IA de hoje é TEMPORÁRIA de propósito, D55 — a
            escolha fina morava na mesa 2D, que saiu no D54/D58)
  campaign: CampaignManager, CampaignRunner, SceneRunner, Dialogue/Choice/BattleTransition
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

> **Estado real em v1.5:** o `ai_preset` está no contrato e o Studio edita, mas o
> runtime **ainda não lê** os 4 números. **D54/D55:** a mesa 2D onde a escolha
> fina da IA vivia (FindKiller + FindBestAttack, a regra do original: direto com o
> mais forte, kill com o mais fraco que vence, melhor margem contra ATK virado
> para cima) foi removida, e o usuário chamou essa IA de **temporária** — vai
> mudar como ela "pensa" na jogada. **D68:** a escolha de hoje mora em
> `astralis/ai/ia_rival.gd`, com DUAS decisões e nada mais — `escolher_invocacao`
> (o índice do monstro na mão) e `escolher_ataque` (o índice do alvo, sendo `-1` o
> ataque direto no jogador). O rival invoca o primeiro monstro e ataca o primeiro
> monstro em campo; a mesa é quem **executa**, pelo mesmo caminho da jogada do
> jogador. Dado pronto, motor pendente — e quando ele for feito, a escolha mora
> em `duel/` (sistema real, testado sem mesa), nunca dentro de um arquivo de tela.

## 5.5 MVP Runtime

Carregar projeto/cartas/duelistas/decks, iniciar duelo, turn flow, summon/attack/damage, victory/defeat, fusion, effect engine inicial, save/load.

## 5.6 [MELHORIA V1.5] Duelista Simples/Avançado + arquétipos

Studio no Simples mostra só: nome, retrato, deck, vida + 3 arquétipos num clique (`Bravo: agressivo+fusão alta | Equilibrado | Defensor: protege LP`). Cada arquétipo preenche os 4 params do preset (dificuldade, agressividade, uso_fusao, protecao_lp). Avançado libera os sliders + dropdown. Runtime não muda: só interpreta os números. Mesma validação nos dois modos.

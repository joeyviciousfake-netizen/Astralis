# 09 — ASTRALIS STUDIO (EDITOR)

ORIGEM: spec v1.1 seções 8, 37, 38, 39, 66, 67, 68, 69, 70, 71

STACK: Rust + Tauri + Svelte.

## 9.1 O que o Studio faz

Criar/abrir/editar projetos; cartas, duelistas (com AI presets V1.2), decks, fusões (receitas+regras), efeitos (templates), campanhas, cenas, importar assets, validar, executar Astralis em preview, criar/executar testes via Astralis.

V1: Project Manager, Card/Duelist/Deck/Fusion Editor, Effect Builder, Campaign/Scene Editor, Asset Manager, Validation, Preview foundation, Test Lab foundation. Preview avançado e Debug UI depois.

## 9.2 UX e poder

Poder = DATA CONTROL + COMPOSABILITY + CONTEXTUAL OPTIONS + VISUAL AUTHORING + RUNTIME CAPABILITIES. Via forms/selectors/blocks/graphs/drag-drop/properties/previews. Sem código.

Campaign Editor tem Graph (Scenes/branching/transitions/battle win/lose) + Timeline (dialogue/character/image/background/sound/music/choice/battle/transition/wait).

UI do jogo: telas estruturais fixas (MainMenu, Campaign, Load, Duel, Deck, Result, Options). V1 não cria tela arbitrária. Usuário edita propriedades permitidas: imagens, textos, fontes, cores, assets, backgrounds, sons, posições permitidas. Exceção: campanha pode ter quantas Scenes quiser, porque Scene é conteúdo.

Assets (card art, characters, portraits, backgrounds, UI, music, SFX): Studio importa/organiza/visualiza/referencia/valida. Astralis carrega/usa/cacheia/libera. Sem lógica de gameplay.

Matriz: Studio cria/edita, Astralis interpreta/executa. Ex.: effect definition Studio cria, Astralis executa; battle rules Astralis responsável, Studio não implementa; preview/teste Astralis executa, Studio controla/inicia.

## 9.3 [MELHORIA V1.2] Starter Kit + Wizard

Todo `New Project` vem com kit jogável mínimo:
- 10 cartas, 2 duelistas (1 fácil/agressivo baixo, 1 normal), 2 decks, 3 fusões (2 receitas + 1 regra), 2 efeitos modelo, 1 campanha com 2 cenas + 1 batalha com win/lose, assets placeholder.

Wizard 3 passos: `1. Duplicar carta -> 2. Montar deck -> 3. Play`. Reduz fricção de tela em branco e já valida pipeline Studio->Astralis no dia 1.

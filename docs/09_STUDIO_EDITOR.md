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

## 9.4 [MELHORIA V1.5] Padrão Simples/Avançado em tudo + galeria

O Modo Simples/Avançado do efeito (doc 07) vira padrão de todos os editores:

- Todo editor abre no Simples (2-3 campos) com botão `Avançado` que libera o resto. Mesmo dado, mesma validação, só muda o que mostra.
- Fusão: Simples = só lista de receitas `A+B=C` + botão `Testar fusão`; Avançado = aba Regras com selects e prioridade.
- Duelista: Simples = nome, retrato, deck, vida + arquétipo num clique (`Bravo | Equilibrado | Defensor`); Avançado = 3 sliders + dropdown de dificuldade.
- Campanha: Simples = modelos de cena e batalha com win/lose já ligado; Avançado = grafo + timeline completos.
- Duelo: Simples = escolher os 2 duelistas + vida + Play; Avançado = seed, arena, ordem de turno.

Galeria de prontos (um clique, tudo duplicável): 10 efeitos modelo, 5 fusões famosas, 3 duelistas arquétipo, 3 campanhas modelo (rival clássico, torneio, final múltiplo). Galeria usa os mesmos schemas; item da galeria é só dado inicial.

Duplicar e editar é a ação principal de toda lista (antes de Criar do zero). Nunca tela em branco.

Assets arrasta e solta: arrastar PNG/JPG/OGG para dentro importa, converte e referencia sozinho; valida tamanho/formato com aviso em PT-BR; se faltar arte, usa placeholder cinza automático para não travar o Play.

Botão verde Jogar em todo editor (carta, deck, duelo, efeito, fusão, cena): salva + lança Astralis com o contexto daquilo (doc 10). Erro de validação aparece em PT-BR simples com botão `Consertar pra mim` quando houver correção segura.

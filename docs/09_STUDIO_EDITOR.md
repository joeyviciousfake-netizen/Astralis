# 09 — ASTRALIS STUDIO (EDITOR)


STACK: Rust + Tauri + Svelte.

## 9.1 O que o Studio faz

Criar/abrir/editar projetos; cartas, duelistas (com AI presets), decks, fusões (receitas+regras), efeitos (templates), campanhas, cenas, importar assets, validar, executar Astralis em preview, criar/executar testes via Astralis.

V1: Project Manager, Card/Duelist/Deck/Fusion Editor, Effect Builder, Campaign/Scene Editor, Asset Manager, Validation, Preview foundation, Test Lab foundation. Preview avançado e Debug UI depois.

## 9.2 UX e poder

Poder = DATA CONTROL + COMPOSABILITY + CONTEXTUAL OPTIONS + VISUAL AUTHORING + RUNTIME CAPABILITIES. Via forms/selectors/blocks/graphs/drag-drop/properties/previews. Sem código.

Campaign Editor tem Graph (Scenes/branching/transitions/battle win/lose) + Timeline (dialogue/character/image/background/sound/music/choice/battle/transition/wait).

UI do jogo: telas estruturais fixas (MainMenu, Campaign, Load, Duel, Deck, Result, Options). V1 não cria tela arbitrária. Usuário edita propriedades permitidas: imagens, textos, fontes, cores, assets, backgrounds, sons, posições permitidas. Exceção: campanha pode ter quantas Scenes quiser, porque Scene é conteúdo.

Assets (card art, characters, portraits, backgrounds, UI, music, SFX): Studio importa/organiza/visualiza/referencia/valida. Astralis carrega/usa/cacheia/libera. Sem lógica de gameplay.

Autoria visual é aberta por padrão: o Studio não mantém blacklist por personagem, franquia, copyright, marca, estilo ou aparência. O usuário escolhe texto, imagens de referência, arte e identidade visual; o Studio não substitui silenciosamente o pedido por uma versão genérica ou "original".

Matriz: Studio cria/edita, Astralis interpreta/executa. Ex.: effect definition Studio cria, Astralis executa; battle rules Astralis responsável, Studio não implementa; preview/teste Astralis executa, Studio controla/inicia.

## 9.3 Starter Kit + Wizard

> **PLANO.** O wizard de 3 passos não existe. O kit que existe é
> `schemas/starter_backup/`: 40 cartas custom, 2 duelistas, 2 decks e 3 receitas
> de fusão. **Não** tem efeito modelo nem campanha. E o `New Project` abre
> **vazio** por decisão (D29): o conteúdo vem só por Importar pack.

O wizard seria `1. Duplicar carta → 2. Montar deck → 3. Play`, depois de importar.
A ideia é reduzir a tela em branco e validar o caminho Studio→Astralis no dia 1.

## 9.4 Padrão Simples/Avançado em tudo + galeria

O Modo Simples/Avançado é o padrão de todos os editores. **Todo editor abre no
Simples (2-3 campos) com botão `Avançado` que libera o resto** — mesmo dado,
mesma validação, só muda o que aparece.

| Editor | Simples | Avançado |
|---|---|---|
| Carta | o essencial, com preview ao vivo | todos os campos do schema |
| Fusão | só a lista de receitas `A+B=C` + `Testar fusão` | a aba de Regras, com selects e prioridade |
| Duelista | nome, retrato, deck, vida e o arquétipo num clique (`Bravo / Equilibrado / Defensor`) | os sliders e o dropdown de dificuldade |
| Duelo | escolher os 2 duelistas, vida e Play | seed, arena, ordem de turno |
| Efeito | a galeria de modelos, 2-3 campos | os blocos `TRIGGER→...` |
| Campanha | **PLANO** (doc 08) | **PLANO** |

> **`Testar fusão` não joga.** O comando existe e valida o **dado**, com a
> mensagem "validado no dado, sem jogar". Isso é o R1: sem motor no runtime, o
> editor não pode executar.
>
> O botão de Play **não** existe no editor de efeitos: sem motor de efeito no
> jogo, o botão seria uma mentira. Por isso `EffectsStudio.svelte` traz um aviso
> fixo no lugar dele.

**Duplicar e editar é a ação principal de toda lista**, antes de Criar do zero.
Nunca tela em branco. A convenção está implementada em `DecksStudio` e
`DuelistsStudio`, que imprimem "Duplicar antes de criar".

Assets arrasta e solta: arrastar PNG/JPG/OGG para dentro importa, converte e
referencia sozinho; valida tamanho e formato com aviso em PT-BR; se faltar arte,
usa placeholder cinza para não travar o Play.

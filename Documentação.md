# ASTRALIS

# MASTER PROJECT SPECIFICATION

VERSION: 1.1
STATUS: AUTHORITATIVE
AUDIENCE: AI AGENTS
LANGUAGE: PT-BR
DOCUMENT TYPE: MASTER ARCHITECTURE / PRODUCT / AGENT SPECIFICATION

---

# 0. OFFICIAL TERMINOLOGY

ASTRALIS:
Runtime oficial do projeto.

ASTRALIS STUDIO:
Editor oficial do projeto.

GODOT:
Engine/framework utilizado para desenvolver o Astralis.

GODOT MCP:
Ferramenta de desenvolvimento utilizada por agentes de IA para operar o ambiente Godot.

GUT:
Framework de testes utilizado durante o desenvolvimento do Astralis.

OPENCODE:
Ferramenta/ambiente de desenvolvimento assistido por IA utilizado para implementação e manutenção do projeto.

IMPORTANTE:

Godot, Godot MCP, GUT e OpenCode NÃO são produtos que o usuário final precisa instalar para utilizar o Astralis Studio ou jogos baseados em Astralis.

---

# 1. PROJECT IDENTITY

Astralis é um runtime 2D especializado em:

* duelo de cartas inspirado em Yu-Gi-Oh! Forbidden Memories;
* campanha em formato visual novel;
* cartas configuráveis;
* duelistas configuráveis;
* decks configuráveis;
* fusões configuráveis;
* efeitos de cartas configuráveis através de uma linguagem visual declarativa;
* campanha altamente configurável;
* interfaces de jogo especializadas e limitadas;
* assets configuráveis.

Astralis Studio é o software de autoria para projetos Astralis.

O objetivo NÃO é criar:

* uma engine genérica de TCG;
* um novo Godot;
* um novo Unreal;
* uma engine de RPG;
* uma ferramenta para criar qualquer tipo de jogo;
* um sistema de scripting genérico.

O objetivo é:

"Permitir que usuários criem seus próprios jogos baseados no modelo de gameplay que Astralis conhece, sem precisar programar."

---

# 2. FUNDAMENTAL PRODUCT MODEL

O produto possui dois componentes de usuário final:

```text
+---------------------------+
|       ASTRALIS STUDIO     |
|                           |
| Editor de projetos        |
+-------------+-------------+
              |
              | Project Data
              v
+---------------------------+
|         ASTRALIS          |
|                           |
| Runtime                   |
| Gameplay                  |
| Campaign                  |
| Effects                   |
| Fusion                    |
| AI                        |
+---------------------------+
              |
              v
            GAME
```

Astralis Studio cria e modifica dados.

Astralis interpreta e executa esses dados.

Astralis Studio NÃO contém uma implementação paralela do gameplay.

Astralis é a autoridade sobre a execução do jogo.

---

# 3. DEVELOPMENT STACK VS PRODUCT STACK

## 3.1 DEVELOPMENT STACK

Utilizado pela equipe/IA para construir o produto:

* OpenCode
* Godot
* Godot MCP
* GUT
* Rust
* Tauri
* Svelte

## 3.2 PRODUCT STACK

Entregue ao usuário:

* Astralis Studio
* Astralis
* Project Data
* Assets

## 3.3 GODOT

Godot é uma ferramenta de desenvolvimento.

O usuário final NÃO deve precisar:

* instalar Godot;
* abrir Godot;
* conhecer Godot;
* configurar Godot;
* executar o projeto Godot.

O projeto Godot é usado para construir o Astralis.

A build exportada do Astralis é o produto.

## 3.4 GODOT MCP

Godot MCP é ferramenta de desenvolvimento.

Funções:

* permitir que agentes de IA interajam com Godot;
* criar/modificar recursos;
* executar operações durante desenvolvimento;
* auxiliar debugging;
* automatizar tarefas.

Godot MCP:

* NÃO faz parte do Astralis;
* NÃO faz parte do Astralis Studio;
* NÃO é requisito do usuário final;
* NÃO deve ser necessário para executar um projeto.

## 3.5 GUT

GUT é ferramenta de testes.

É usada para:

* unit tests;
* integration tests;
* regression tests;
* runtime tests durante desenvolvimento.

GUT:

* NÃO é parte do gameplay;
* NÃO é requisito do usuário final;
* NÃO deve ser empacotado no produto final sem necessidade;
* NÃO deve conter lógica alternativa do jogo.

---

# 4. CORE ARCHITECTURAL PRINCIPLE

REGRA ABSOLUTA:

DATA != LOGIC

Dados definem conteúdo.

Astralis define comportamento.

EXEMPLOS:

Card name = DATA
Card ATK = DATA
Card DEF = DATA
Card artwork = DATA
Card effect definition = DATA

Effect execution = ASTRALIS LOGIC

Battle resolution = ASTRALIS LOGIC

Turn processing = ASTRALIS LOGIC

AI decision = ASTRALIS LOGIC

Campaign execution = ASTRALIS LOGIC

---

# 5. SECOND CORE PRINCIPLE

ASTRALIS STUDIO NEVER IMPLEMENTS GAMEPLAY LOGIC.

Astralis Studio:

* cria dados;
* edita dados;
* valida dados;
* visualiza dados;
* inicia Astralis;
* solicita modos de preview;
* solicita modos de teste.

Astralis:

* interpreta dados;
* executa gameplay;
* executa efeitos;
* executa duelo;
* executa campanha;
* executa IA;
* controla game state.

Não implementar no Astralis Studio:

* BattleSystem alternativo;
* EffectSystem alternativo;
* FusionSystem alternativo;
* TurnSystem alternativo;
* AI alternativa.

---

# 6. NO PARALLEL GAMEPLAY ENGINE

PROIBIDO:

Astralis Studio possuir:

```text
FakeDuelEngine
FakeEffectEngine
FakeFusionEngine
FakeCampaignRunner
```

Mesmo que esses sistemas sejam apenas para preview.

Preview deve utilizar Astralis.

Test Lab deve utilizar Astralis.

O usuário deve ver o comportamento real do runtime.

---

# 7. ASTRALIS

Astralis é o runtime oficial.

Astralis é desenvolvido em Godot.

Após compilado/exportado, Astralis funciona como aplicativo executável independente da instalação do Godot.

O usuário final utiliza Astralis, não Godot.

Exemplo conceitual:

```text
DESENVOLVIMENTO

Godot Project
     |
     v
Astralis Build
```

PRODUTO:

```text
Astralis
```

Astralis deve conseguir:

* carregar um Project Data válido;
* executar campanha;
* executar duelos;
* carregar cartas;
* carregar duelistas;
* carregar decks;
* resolver fusões;
* executar efeitos;
* executar IA;
* salvar/carregar progresso;
* executar áudio;
* renderizar UI;
* executar modos especiais de desenvolvimento quando apropriado.

---

# 8. ASTRALIS STUDIO

Astralis Studio é o editor oficial.

Tecnologias:

* Rust;
* Tauri;
* Svelte.

Astralis Studio deve permitir:

* criar projetos;
* abrir projetos;
* editar projetos;
* criar cartas;
* editar cartas;
* criar duelistas;
* editar duelistas;
* criar decks;
* editar decks;
* criar fusões;
* editar fusões;
* criar efeitos;
* editar efeitos;
* criar campanhas;
* editar campanhas;
* editar cenas;
* importar assets;
* validar projetos;
* executar Astralis em preview;
* criar testes;
* executar testes através de Astralis.

---

# 9. PROJECT DATA

Astralis Studio produz Project Data.

Project Data deve ser independente do código-fonte do Astralis.

Estrutura conceitual:

```text
project/
    project.json

    cards/
        ...

    duelists/
        ...

    decks/
        ...

    fusions/
        ...

    effects/
        ...

    campaigns/
        ...

    assets/
        cards/
        characters/
        portraits/
        backgrounds/
        music/
        sfx/
        ui/

    tests/
        ...
```

Arquivos podem evoluir.

Princípio obrigatório:
dados devem permanecer separados da lógica.

---

# 10. DATA CONTRACT

Astralis e Astralis Studio devem compartilhar um contrato de dados.

Exemplos:

* Project Schema;
* Card Schema;
* Duelist Schema;
* Deck Schema;
* Fusion Schema;
* Effect Schema;
* Campaign Schema;
* Scene Schema;
* Test Scenario Schema.

O schema define:

* tipos;
* campos;
* referências;
* valores permitidos;
* enums;
* estruturas;
* versões.

Astralis Studio usa o schema para edição e validação.

Astralis usa o mesmo contrato para carregamento e validação.

---

# 11. SCHEMA VERSIONING

Todo projeto deve conter:

```text
schema_version
```

Exemplo:

```text
schema_version: 1
```

Mudanças incompatíveis exigem:

* nova versão;
* estratégia de migração;
* ou incompatibilidade explicitamente documentada.

Nunca alterar comportamento estrutural do schema de maneira silenciosa.

---

# 12. RESOURCE IDS

Todos os recursos possuem IDs estáveis.

Exemplos:

```text
card_dark_magician
duelist_yugi
deck_yugi_default
fusion_dark_magician_001
campaign_chapter_01
scene_castle_intro
effect_fire_warrior_001
```

ID NÃO deve depender do nome exibido.

EXEMPLO:

```text
id: card_dark_magician
name: Dark Magician
```

Pode virar:

```text
id: card_dark_magician
name: Mago Sombrio
```

O ID permanece.

---

# 13. RUNTIME MODULES

Estrutura conceitual:

```text
astralis/
    core/
        GameState
        DataLoader
        ProjectLoader
        SaveSystem
        EventBus
        RuntimeValidator

    duel/
        DuelManager
        TurnManager
        BattleSystem
        SummonSystem
        DamageSystem
        PositionSystem
        FusionSystem
        EffectSystem
        AIController

    campaign/
        CampaignManager
        CampaignRunner
        SceneRunner
        DialogueSystem
        ChoiceSystem
        TransitionSystem
        BattleTransition

    ui/
        MainMenu
        CampaignUI
        DuelUI
        DeckUI
        ResultUI
        LoadUI
        OptionsUI

    assets/
        AssetLoader
        ResourceCache
        AudioManager

    debug/
        DebugConsole
        StateInspector
        EventInspector

    testing/
        TestHarness
        TestRunner
        TestReporter
```

Nomes e organização interna podem mudar.

Responsabilidades devem permanecer equivalentes.

---

# 14. DUEL SYSTEM

Astralis implementa as regras estruturais do duelo.

REGRAS FIXAS:

* fluxo de turno;
* processamento do duelo;
* regras estruturais de invocação;
* regras estruturais de batalha;
* resolução de dano;
* estrutura dos estados de duelo;
* regras internas do jogo;
* AI do oponente.

CONTEÚDO EDITÁVEL:

* cartas;
* ATK;
* DEF;
* atributos;
* tipos;
* decks;
* duelistas;
* LP inicial;
* efeitos;
* fusões;
* recompensas;
* conteúdo visual.

---

# 15. DUEL RULES VS GAME DATA

IMPORTANTE:

"Regra do duelo" != "parâmetro do duelo"

Exemplo:

"Existe um sistema de LP" = runtime rule.

"Começar com 8000 LP" = editable data.

"Existe ataque" = runtime rule.

"Monstro possui 2500 ATK" = editable data.

"Existe Fusion System" = runtime capability.

"Dark Magician + X resulta em Y" = editable data.

---

# 16. DUELIST SYSTEM

Duelist é data-driven.

Modelo conceitual:

```text
Duelist
    id
    name
    portrait
    sprite
    deck_id
    starting_lp
    music
    arena/background
    dialogue references
    reward configuration
```

A IA é runtime-owned.

V1:
todos os duelistas utilizam a mesma base de IA.

V1 NÃO implementa:

* custom AI scripting;
* IA programável pelo usuário.

Futuro:

* AI difficulty;
* AI profiles;
* behavior parameters.

---

# 17. DECK SYSTEM

Deck é data.

```text
Deck
    id
    name
    cards[]
```

Deck referencia Card IDs.

Deck não contém lógica.

Deck não deve duplicar os objetos completos das cartas.

---

# 18. CARD SYSTEM

Card é data.

Modelo conceitual:

```text
Card
    id
    name
    description
    artwork
    frame/style
    card_type
    monster_type
    attribute
    level
    attack
    defense
    effects[]
    tags[]
```

Campos podem evoluir.

Não criar scripts individuais de cartas.

---

# 19. FUSION SYSTEM

Astralis implementa o algoritmo de fusão.

Project Data define as receitas.

Exemplo:

```text
input:
    card_a
    card_b

result:
    card_c
```

O usuário pode:

* criar;
* editar;
* remover;
* duplicar;
* validar recipes.

V1:
priorizar recipes explícitas e determinísticas.

Fusion recipes não devem ficar hardcoded como lógica permanente no runtime.

---

# 20. EFFECT SYSTEM

Effect System é uma das arquiteturas centrais do projeto.

Objetivo:

Permitir grande liberdade dentro de capacidades suportadas por Astralis.

O usuário NÃO programa.

O usuário combina blocos declarativos.

Estrutura conceitual:

```text
TRIGGER
    ->
CONDITIONS
    ->
TARGET
    ->
ACTIONS
    ->
FLOW
```

---

# 21. EFFECT TRIGGERS

Possíveis triggers:

* card_summoned;
* card_destroyed;
* attack_started;
* attack_finished;
* damage_dealt;
* damage_received;
* turn_started;
* turn_finished;
* card_drawn;
* card_sent_to_graveyard;
* fusion_performed;
* card_equipped.

Lista oficial depende das capacidades implementadas em Astralis.

Regra:
um trigger só pode existir no Astralis Studio quando Astralis sabe executá-lo.

---

# 22. EFFECT CONDITIONS

Exemplos:

* attack > value;
* attack < value;
* defense > value;
* defense < value;
* attribute == X;
* monster_type == X;
* card_in_field;
* card_in_graveyard;
* card_in_hand;
* player_lp > X;
* opponent_lp < X;
* exists_card(X);
* not_exists_card(X).

O editor deve restringir combinações inválidas.

---

# 23. EFFECT TARGETS

Exemplos:

* self;
* ally_monster;
* enemy_monster;
* all_ally_monsters;
* all_enemy_monsters;
* random_card;
* selected_card;
* card_in_graveyard;
* card_in_hand.

Targets devem possuir compatibilidade declarada com Actions.

---

# 24. EFFECT ACTIONS

Exemplos iniciais:

* modify_attack;
* modify_defense;
* damage;
* heal;
* destroy;
* draw;
* discard;
* summon;
* change_position;
* change_attribute;
* change_type;
* equip;
* add_to_hand;
* remove_from_field.

Cada Action nova exige:

1. schema;
2. runtime implementation;
3. editor UI;
4. validation;
5. tests;
6. documentation.

---

# 25. EFFECT FLOW

Possibilidades:

* sequence;
* if;
* else;
* repeat;
* stop.

V1 pode começar com:

* multiple actions;
* sequence.

Conditional flow avançado deve ser introduzido após a base estar estável.

Não transformar o Effect System em uma linguagem de programação geral.

---

# 26. MULTIPLE EFFECTS

Uma carta pode possuir múltiplos efeitos.

Exemplo:

```text
Effect 1:
    trigger = card_summoned
    action = draw

Effect 2:
    trigger = card_summoned
    action = modify_attack

Effect 3:
    trigger = card_summoned
    condition = ...
    action = destroy
```

Effects são data.

Effect execution pertence ao Astralis.

---

# 27. HUMAN-READABLE EFFECT DESCRIPTION

Astralis Studio deve gerar descrição humana derivada da definição do efeito.

Exemplo:

Dados:

```text
trigger = card_summoned
target = enemy_monster
action = modify_attack
value = -500
duration = turn_end
```

Representação:

"Quando esta carta for invocada, reduza o ATK de 1 monstro do oponente em 500 até o fim do turno."

Texto é derivado.
Texto NÃO é a fonte da lógica.

---

# 28. EFFECT VALIDATION

Astralis Studio:

* faz validação para UX.

Astralis:

* faz validação ao carregar/executar.

Estados:

```text
VALID
WARNING
ERROR
```

Exemplos de ERROR:

* trigger inexistente;
* action inexistente;
* target incompatível;
* campo obrigatório ausente;
* referência inexistente;
* parâmetro inválido.

Nunca permitir erro crítico silencioso.

---

# 29. EFFECT BUILDER

Effect Builder deve ser contextual.

Exemplo:

Action = modify_attack

Mostrar:

* target;
* value;
* duration.

Action = draw

Mostrar:

* amount.

Action = destroy

Mostrar:

* target.

Não mostrar campos irrelevantes.

Objetivo:
maximizar poder através de composição, não através de exposição de complexidade.

---

# 30. EFFECT COMPLEXITY LEVELS

LEVEL 1:

```text
Trigger
   ->
Action
```

LEVEL 2:

```text
Trigger
   ->
Condition
   ->
Target
   ->
Action
```

LEVEL 3:

```text
Trigger
   ->
Conditions
   ->
Targets
   ->
Multiple Actions
   ->
Flow
```

Astralis pode possuir modelo unificado.

Astralis Studio pode esconder complexidade conforme o caso.

---

# 31. CAMPAIGN SYSTEM

Campanha é uma Visual Novel 2D.

Usuário pode controlar:

* história;
* ordem das cenas;
* diálogos;
* personagens;
* backgrounds;
* escolhas;
* transições;
* batalhas;
* fluxo.

Campanha é data-driven.

---

# 32. CAMPAIGN GRAPH

Campanha é modelada como grafo.

Exemplo:

```text
Scene A
    |
    v
Dialogue
    |
    v
Choice
   / \
  v   v
Scene B
Scene C
   \ /
    v
  Battle
    |
    v
Scene D
```

GRAPH:
controla fluxo global.

---

# 33. CAMPAIGN SCENE

Scene contém conteúdo ordenado.

Modelo:

```text
Scene
    id
    background
    music
    elements[]
```

Elements podem incluir:

* dialogue;
* character;
* image;
* choice;
* battle;
* transition;
* sound;
* music;
* wait;
* jump;
* next scene.

---

# 34. CAMPAIGN TIMELINE

Dentro de uma Scene, os elementos possuem ordem.

Exemplo:

```text
Background
Character
Dialogue
Character
Dialogue
Transition
Battle
Dialogue
Next Scene
```

Graph:
define para onde ir.

Timeline:
define o que acontece dentro da cena.

---

# 35. CAMPAIGN CHOICES

Choices são suportadas na V1.

Exemplo:

```text
"Sim" -> scene_b
"Não" -> scene_c
```

V1 NÃO exige:

* persistent variables;
* reputation;
* quests;
* inventory;
* advanced state logic.

---

# 36. VARIABLES

Variables NÃO fazem parte do núcleo V1.

Possível futura implementação:

* boolean;
* integer;
* string;
* flags;
* counters;
* conditions.

Só introduzir após estabilização de:

* runtime;
* campaign system;
* editor;
* preview.

---

# 37. GAME UI

Astralis possui telas estruturais predefinidas.

Exemplos:

* Main Menu;
* Campaign;
* Load;
* Duel;
* Deck;
* Result;
* Options.

Astralis Studio NÃO permite criar qualquer tela arbitrária na V1.

Usuário pode editar propriedades visuais permitidas:

* imagens;
* textos;
* fontes;
* cores;
* assets;
* backgrounds;
* sons;
* música;
* posições que o runtime permitir.

A estrutura funcional da UI permanece sob controle de Astralis.

---

# 38. CAMPAIGN UI EXCEPTION

Campanha é flexível.

Usuário pode criar quantas Scenes forem necessárias.

Isto é permitido porque Scenes de campanha são conteúdo.

Criar novas categorias arbitrárias de telas do jogo NÃO é permitido na V1.

---

# 39. ASSET SYSTEM

Assets incluem:

* card art;
* characters;
* portraits;
* backgrounds;
* UI;
* music;
* SFX;
* effects/visual assets.

Astralis Studio:

* importa;
* organiza;
* visualiza;
* referencia;
* valida.

Astralis:

* carrega;
* usa;
* cacheia;
* libera.

Assets não contêm lógica de gameplay.

---

# 40. PREVIEW SYSTEM

IMPORTANTE:
Preview NÃO é Test Lab.

Preview serve para:
"ver o conteúdo funcionando."

Test Lab serve para:
"verificar automaticamente se o comportamento está correto."

Ambos utilizam Astralis.

Nenhum dos dois possui uma implementação independente de gameplay no Astralis Studio.

---

# 41. PREVIEW MODES

Existem diferentes níveis de Preview.

## 41.1 PROJECT PLAY

Executa o projeto normalmente.

```text
Astralis Studio
    |
    v
Launch Astralis
    |
    v
Game
```

O usuário joga normalmente.

## 41.2 SCENE PREVIEW

Posteriormente:
abre Astralis diretamente em uma Scene específica.

Objetivo:
não precisar iniciar campanha desde o início.

## 41.3 DUEL PREVIEW

Posteriormente:
abre um duelo previamente configurado.

Exemplo:

* player;
* opponent;
* decks;
* LP;
* field;
* hand.

## 41.4 EFFECT PREVIEW

Posteriormente:
abre uma visualização de duelo preparada para experimentar um efeito de carta.

Exemplo:

```text
Card Editor
    |
    v
Preview Effect
    |
    v
Astralis
    |
    v
Duel Preview State
    |
    v
Effect executes
```

## 41.5 FUSION PREVIEW

Posteriormente:
visualiza uma fusão utilizando FusionSystem real.

---

# 42. PREVIEW IMPLEMENTATION RULE

Astralis Studio NÃO calcula o efeito.

Astralis Studio apenas cria/prepara o cenário e solicita execução.

Exemplo:

```text
Astralis Studio
    |
    | Test/Preview Scenario
    v
Astralis
    |
    v
GameState
    |
    v
EffectSystem
    |
    v
Result
```

O mesmo EffectSystem usado no jogo é usado no Preview.

---

# 43. PREVIEW TIMING

Preview avançado NÃO é prioridade inicial.

Roadmap:

V1:
sem contextual preview avançado.

V2:
Play Project.

V3:
Scene Preview.

V4:
Duel Preview.

V5:
Effect Preview.

V6:
Fusion Preview.

Esses nomes são conceituais.
Podem ser reorganizados conforme desenvolvimento.

---

# 44. TEST LAB

Test Lab é uma área interna do Astralis Studio.

Objetivo:
criar e executar testes de comportamento do conteúdo.

Test Lab NÃO implementa gameplay.

Test Lab cria:

* Test Scenarios;
* setups;
* actions;
* assertions;
* expected results.

Astralis executa os testes.

---

# 45. TEST LAB VS PREVIEW

PREVIEW:

Objetivo:
experimentação visual/interativa.

Exemplo:
"Quero ver essa carta funcionando."

TEST LAB:

Objetivo:
verificação determinística e repetível.

Exemplo:
"Quero garantir que quando a carta for invocada o ATK do alvo caia de 2000 para 1500."

---

# 46. TEST SCENARIO MODEL

Estrutura conceitual:

```text
TEST
    SETUP
    GIVEN
    WHEN
    THEN
```

Exemplo:

```text
TEST:
Fire Warrior Effect

GIVEN:
Player LP = 4000
Opponent LP = 4000
Enemy Monster ATK = 2000

WHEN:
Summon Fire Warrior

THEN:
Enemy Monster ATK == 1500
```

O usuário monta isso visualmente.

Nenhum código é escrito pelo usuário.

---

# 47. TEST SETUP

Test Setup inicializa o GameState.

Pode definir:

* player LP;
* opponent LP;
* cards in hand;
* cards in field;
* cards in graveyard;
* deck;
* duelists;
* current phase;
* turn;
* campaign scene;
* outros dados suportados.

Test Setup NÃO implementa gameplay.

É apenas inicialização de estado.

---

# 48. TEST ACTIONS

Test Actions podem solicitar operações ao Astralis.

Exemplos:

* summon card;
* attack;
* activate effect;
* end turn;
* draw;
* fuse;
* advance campaign scene;
* choose option;
* execute event.

Essas operações devem passar pelos sistemas reais do Astralis.

---

# 49. TEST ASSERTIONS

Assertions verificam o estado real retornado por Astralis.

Exemplos:

```text
player_lp == 4000

opponent_lp == 3500

card_exists(field, X)

card_not_exists(field, Y)

card_attack(X) == 1500

current_scene == scene_004

fusion_result == card_ultimate_dragon
```

O editor não calcula o resultado.

Ele compara:
EXPECTED vs ACTUAL.

---

# 50. TEST EXECUTION

Fluxo:

```text
Astralis Studio
    |
    v
Test Scenario
    |
    v
Astralis Test Harness
    |
    v
Initialize GameState
    |
    v
Execute Actions
    |
    v
Real Game Systems
    |
    v
Assertions
    |
    v
TestResult
    |
    v
Astralis Studio
```

---

# 51. TEST HARNESS

Astralis deve possuir um modo interno de execução de testes.

Conceitualmente:

```text
TestHarness
    create_game_state()
    inject_card()
    inject_duelist()
    set_lp()
    set_field()
    set_hand()
    emit_event()
    execute_test_action()
    advance_state()
    capture_state()
    inspect_events()
```

Essas operações NÃO implementam gameplay.

Elas:

* preparam;
* controlam;
* observam;
* registram.

Gameplay continua nos sistemas reais.

---

# 52. TEST HARNESS RULE

PROIBIDO:

```text
TestHarness:
    custom_damage_calculation()
    custom_fusion_logic()
    custom_effect_execution()
```

CORRETO:

```text
TestHarness:
    prepare_state()
    call_real_battle_system()
    capture_result()
```

---

# 53. TEST TRACE

Test Lab deve poder mostrar um trace.

Exemplo:

```text
TEST PASSED

Summon Card
    |
card_summoned
    |
Effect #effect_012 triggered
    |
Condition = TRUE
    |
Target selected = Monster A
    |
modify_attack(-500)
    |
Monster A ATK
2000 -> 1500
    |
Assertion:
ATK == 1500
    |
PASS
```

Trace deve utilizar eventos/snapshots reais do Astralis.

---

# 54. TEST FAILURE

Falha deve possuir:

* expected;
* actual;
* trace;
* state_before;
* state_after;
* relevant events;
* error information.

Exemplo:

```text
FAILED

Expected:
ATK = 1500

Actual:
ATK = 2000

Trace:
card_summoned
effect_012 triggered
target selected
action failed
```

Objetivo:
facilitar debugging humano e por IA.

---

# 55. STATE INSPECTOR

Durante Preview/Test/Debug, Astralis pode expor estado.

Exemplo:

```text
SCENE
castle_intro

TURN
7

PLAYER
LP 4000

OPPONENT
LP 2500

PLAYER FIELD
Dark Magician
ATK 2500

OPPONENT FIELD
Blue Eyes
ATK 3000

HAND
5 cards

GRAVEYARD
3 cards

ACTIVE EFFECTS
effect_021

EVENT QUEUE
damage_resolved
```

Astralis Studio pode visualizar isso.

---

# 56. STATE DIFF

Test/Preview pode apresentar diferença de estado.

Antes:

```text
Opponent LP = 4000
Monster ATK = 2000
```

Depois:

```text
Opponent LP = 3500
Monster ATK = 1500
```

UI:

```text
STATE CHANGES

Opponent LP
4000 -> 3500

Monster ATK
2000 -> 1500
```

---

# 57. CAMPAIGN DEBUGGER

Posteriormente, Astralis Studio poderá permitir:

```text
Play
Pause
Step
Restart
```

durante Scene Preview.

Pode mostrar:

* current scene;
* current node;
* current dialogue;
* current character;
* current state;
* active effects.

---

# 58. BREAKPOINTS

Futuro recurso.

Usuário pode marcar um elemento de campanha como breakpoint.

Durante Preview:

```text
Scene: castle_intro
Node: dialogue_017

PAUSED
```

Astralis Studio inspeciona estado.

Breakpoint é ferramenta de desenvolvimento/autoria.

Não altera a lógica do jogo.

---

# 59. TEST RECORDING

Futuro recurso.

Usuário executa ações durante um Preview.

Astralis registra eventos.

Exemplo:

```text
Summon Fire Warrior
Attack Monster A
End Turn
```

Usuário pode salvar sequência como Test Scenario.

Isso deve gerar dados de teste.

Não gerar código.

---

# 60. SMART TEST SETUP

Future feature.

Ao clicar:

```text
Test Effect
```

Astralis Studio pode analisar a estrutura do efeito e sugerir um cenário.

Exemplo:

Effect exige:

* triggering card;
* enemy monster;
* target.

Studio cria:

```text
Player:
Testing Card

Opponent:
Test Monster
ATK 2000
```

Importante:
o Studio pode sugerir o setup.

O Studio NÃO calcula o resultado do efeito.

Resultado continua vindo do Astralis.

---

# 61. DETERMINISM

Testes devem ser determinísticos sempre que possível.

Astralis deve suportar controle de:

* random seed;
* RNG;
* input;
* tempo;
* execução;
* eventos aleatórios.

Exemplo:

```text
TEST MODE
seed = 12345
```

Objetivo:
mesmo Test Scenario + mesma seed = mesmo comportamento esperado.

Essencial para:

* random cards;
* random targets;
* random effects;
* IA;
* futuros sistemas aleatórios.

---

# 62. TEST LAYERS

Existem três camadas de testes.

## LAYER 1 — PROJECT VALIDATION

Não executa gameplay.

Verifica:

* schema;
* IDs;
* referências;
* assets;
* tipos;
* campos;
* compatibilidade.

## LAYER 2 — ASTRALIS TEST LAB

Executa gameplay real.

Verifica:

* effects;
* duel;
* fusion;
* campaign;
* scenes;
* interactions.

## LAYER 3 — GUT

Testa internamente o código do Astralis.

Verifica:

* sistemas;
* componentes;
* regressões;
* integração técnica.

---

# 63. GUT VS TEST LAB

GUT é developer-oriented.

Test Lab é content-author-oriented.

GUT:
"EffectResolver correctly processes action X."

Test Lab:
"Esta carta, com esta configuração, deveria destruir este monstro."

GUT:
"BattleSystem calculates damage correctly."

Test Lab:
"Neste duelo, quando A ataca B, B é destruído e LP é alterado desta forma."

Os dois são complementares.

---

# 64. GUT DEVELOPMENT POLICY

Sistemas críticos do Astralis devem possuir testes GUT.

Prioridade:

* DataLoader;
* Validation;
* GameState;
* TurnManager;
* BattleSystem;
* DamageSystem;
* FusionSystem;
* EffectSystem;
* CampaignRunner;
* SaveSystem.

---

# 65. DEBUG SYSTEM

Astralis deve possuir ferramentas de debug em builds de desenvolvimento.

Possíveis informações:

* GameState;
* active scene;
* active effect;
* event queue;
* cards;
* field;
* LP;
* AI decisions;
* errors;
* warnings.

Objetivo:
permitir diagnóstico preciso.

---

# 66. EDITOR MODULES

Astralis Studio V1:

* Project Manager;
* Card Editor;
* Duelist Editor;
* Deck Editor;
* Fusion Editor;
* Effect Builder;
* Campaign Editor;
* Scene Editor;
* Asset Manager;
* Validation;
* Preview foundation;
* Test Lab foundation.

Advanced Preview e Debug UI podem ser adicionados depois.

---

# 67. EDITOR UX PRINCIPLES

Astralis Studio deve parecer:

* simples;
* moderno;
* visual;
* contextual;
* poderoso;
* especializado.

Não deve parecer:

* Godot;
* Unreal;
* IDE;
* programming environment.

Usuário não precisa:

* programar;
* escrever GDScript;
* escrever Rust;
* escrever Svelte;
* escrever JSON manualmente.

---

# 68. EDITOR POWER MODEL

Poder do editor vem de:

```text
DATA CONTROL
+
COMPOSABILITY
+
CONTEXTUAL OPTIONS
+
VISUAL AUTHORING
+
RUNTIME CAPABILITIES
```

Não vem de:

* scripting;
* plugins arbitrários;
* custom code.

---

# 69. UI CUSTOMIZATION LIMIT

V1:
usuário pode editar propriedades visuais permitidas.

Pode:

* trocar imagens;
* trocar backgrounds;
* trocar textos;
* alterar fontes;
* alterar cores;
* alterar assets;
* ajustar propriedades permitidas pelo runtime.

Não pode:

* criar qualquer widget;
* criar qualquer sistema de layout;
* criar novas telas arbitrárias;
* programar comportamento de UI.

---

# 70. CAMPAIGN EDITOR

A campanha deve ter duas visualizações principais:

## GRAPH

Mostra:

* Scenes;
* branching;
* transitions;
* battle nodes.

## SCENE/TIMELINE

Mostra:

* dialogue;
* character;
* image;
* background;
* sound;
* music;
* choice;
* battle;
* transition;
* wait.

Graph = fluxo global.

Timeline = conteúdo local.

---

# 71. RUNTIME/EDITOR RESPONSIBILITY MATRIX

| Recurso                | Astralis      | Astralis Studio   |
| ---------------------- | ------------- | ----------------- |
| Card data              | interpreta    | cria/edita        |
| Card artwork           | carrega       | importa/configura |
| Card effect definition | executa       | cria/edita        |
| Effect execution       | responsável   | não executa       |
| Battle rules           | responsável   | não implementa    |
| Fusion execution       | responsável   | não implementa    |
| Fusion recipes         | carrega       | cria/edita        |
| Duelist data           | interpreta    | cria/edita        |
| Duelist AI             | responsável   | não implementa    |
| Campaign data          | executa       | cria/edita        |
| Campaign graph         | interpreta    | cria/edita        |
| Scene content          | executa       | cria/edita        |
| Project validation     | valida        | valida para UX    |
| Preview                | executa       | controla/inicia   |
| Test execution         | executa       | configura/exibe   |
| Gameplay debugging     | fornece dados | visualiza         |

---

# 72. PROJECT PREVIEW ARCHITECTURE

Fluxo:

```text
ASTRALIS STUDIO
    |
    | save project
    v
Project Data
    |
    | launch
    v
ASTRALIS
    |
    v
load project
    |
    v
run
```

Astralis Studio não precisa conhecer internamente o Godot.

Astralis Studio conhece:

* Astralis executable;
* project format;
* preview arguments/protocol.

---

# 73. RUNTIME DISTRIBUTION

Astralis deve ser distribuído como runtime independente.

Exemplo conceitual:

```text
Astralis Studio
Astralis
Project Data
Assets
```

O usuário não instala:

* Godot;
* Godot MCP;
* GUT;
* OpenCode.

---

# 74. RUNTIME COMMUNICATION

Astralis Studio e Astralis precisam possuir um mecanismo de comunicação definido.

Inicialmente pode ser simples:

* argumentos de inicialização;
* arquivos temporários;
* projeto em diretório compartilhado;
* status/result files;
* IPC posteriormente.

Não decidir prematuramente uma arquitetura IPC complexa.

Primeiro estabelecer:

* Project Data contract;
* command contract;
* result contract.

---

# 75. ASTRALIS COMMAND MODES

Astralis pode possuir modos internos:

```text
GAME
PREVIEW
TEST
DEBUG
```

Esses modos utilizam os mesmos sistemas de gameplay.

Diferença:

* inicialização;
* observabilidade;
* controle;
* apresentação.

---

# 76. GAME MODE

Modo normal.

Usuário joga.

Sem ferramentas de teste.

---

# 77. PREVIEW MODE

Modo de autoria.

Permite:

* iniciar projeto;
* iniciar cena;
* iniciar duelo;
* executar conteúdo selecionado;
* inspecionar, quando suportado.

Usa gameplay real.

---

# 78. TEST MODE

Modo de execução de Test Scenarios.

Permite:

* setup;
* actions;
* assertions;
* trace;
* snapshots;
* resultado estruturado.

Usa gameplay real.

---

# 79. DEBUG MODE

Modo destinado ao desenvolvimento do Astralis.

Pode mostrar:

* logs;
* state;
* events;
* timing;
* AI;
* internal diagnostics.

---

# 80. AGENT TEAM

Equipe principal:

1. Lead Architect
2. Runtime Engineer
3. Systems/Data Engineer
4. Campaign Engineer
5. Editor Engineer
6. QA/Integration Engineer

Não criar dezenas de agentes.

Especialização deve ser por domínio arquitetural.

---

# 81. LEAD ARCHITECT

Responsável por:

* arquitetura;
* contratos;
* invariantes;
* documentação;
* integração;
* decisões estruturais.

Não é dono exclusivo de toda implementação.

Deve impedir:

* hardcoding;
* scripting arbitrário;
* duplicação de logic;
* editor gameplay;
* engine genericization;
* schema inconsistency.

---

# 82. RUNTIME ENGINEER

Responsável por:

* Astralis;
* Duel Engine;
* Effect Engine execution;
* Fusion Engine execution;
* AI;
* Save/Load;
* runtime UI;
* DataLoader;
* runtime Preview/Test modes.

Não é responsável por:

* Svelte;
* Tauri;
* editor frontend.

---

# 83. SYSTEMS/DATA ENGINEER

Responsável por:

* schemas;
* data models;
* validation;
* Card;
* Duelist;
* Deck;
* Fusion Recipe;
* Effect definition;
* serialization.

Owner do contrato de dados.

---

# 84. CAMPAIGN ENGINEER

Responsável por:

* Campaign runtime;
* SceneRunner;
* Dialogue;
* Choice;
* Timeline execution;
* Campaign graph execution;
* Battle transition.

Não deve criar formato de dados isoladamente.
Deve respeitar schema compartilhado.

---

# 85. EDITOR ENGINEER

Responsável por:

* Astralis Studio;
* Rust;
* Tauri;
* Svelte;
* Card Editor;
* Duelist Editor;
* Deck Editor;
* Fusion Editor;
* Effect Builder;
* Campaign Editor;
* Asset Manager;
* Validation UI;
* Preview UI;
* Test Lab UI.

Não deve implementar gameplay alternativo.

---

# 86. QA / INTEGRATION ENGINEER

Responsável por:

* GUT;
* integration tests;
* regression;
* Test Lab infrastructure validation;
* Project validation;
* editor/runtime compatibility;
* build validation.

---

# 87. AGENT OWNERSHIP

Conceitualmente:

```text
docs/
architecture/
    -> Lead Architect

astralis/
    -> Runtime Engineer

schemas/
data-model/
    -> Systems/Data Engineer

campaign/
    -> Campaign Engineer

astralis-studio/
    -> Editor Engineer

tests/
tools/
ci/
    -> QA
```

Shared changes devem ser coordenadas.

---

# 88. AGENT RULE

Todos os agentes devem:

1. Ler esta especificação.
2. Ler documentação do próprio domínio.
3. Respeitar invariantes.
4. Não inventar requisitos.
5. Não ampliar escopo sem necessidade.
6. Não duplicar gameplay logic.
7. Adicionar/atualizar testes.
8. Atualizar documentação quando necessário.
9. Preferir mudanças pequenas.
10. Preservar compatibilidade.

---

# 89. FEATURE DEVELOPMENT PROTOCOL

Nova feature:

1. definir comportamento;
2. verificar impacto;
3. definir data contract;
4. implementar Astralis;
5. implementar Astralis Studio;
6. adicionar testes;
7. integrar;
8. documentar.

Não iniciar uma feature pelo UI se a capacidade runtime ainda não existe.

---

# 90. CROSS-DOMAIN FEATURE EXAMPLE

Nova Action de Effect:

SYSTEMS/DATA:

* adicionar schema;
* parâmetros;
* validação.

RUNTIME:

* executar Action.

EDITOR:

* criar bloco;
* mostrar parâmetros;
* validar;
* gerar descrição.

QA:

* GUT;
* Test Lab scenario;
* regression.

ARCHITECT:

* verificar boundaries;
* atualizar docs.

---

# 91. TEST-FIRST BEHAVIOR

Para sistemas críticos:

SPEC
->
TEST
->
IMPLEMENT
->
RUN
->
FIX
->
REGRESSION

Quando um bug for encontrado:

1. criar teste reproduzindo;
2. corrigir;
3. manter teste permanentemente.

---

# 92. MVP RUNTIME

Primeiro objetivo funcional:

* carregar projeto;
* carregar cartas;
* carregar duelistas;
* carregar decks;
* iniciar duelo;
* turn flow;
* summon;
* attack;
* damage;
* victory;
* defeat;
* fusion;
* effect engine inicial;
* save/load.

---

# 93. MVP EFFECT ENGINE

Initial Triggers:

* card_summoned;
* card_destroyed;
* turn_started;
* turn_finished;
* attack_started;
* damage_dealt.

Initial Actions:

* modify_attack;
* modify_defense;
* damage;
* heal;
* destroy;
* draw;
* discard.

Initial Targets:

* self;
* ally_monster;
* enemy_monster;
* all_ally_monsters;
* all_enemy_monsters.

Expandir gradualmente.

---

# 94. MVP EDITOR

Primeiro:

* Project;
* Card;
* Duelist;
* Deck;
* Fusion;
* Effect;
* Validation.

Depois:

* Campaign;
* Preview;
* Test Lab.

Preview avançado não é prioridade inicial.

---

# 95. MVP CAMPAIGN

Initial elements:

* Scene;
* Dialogue;
* Character;
* Background;
* Choice;
* Battle;
* Transition;
* Wait;
* Sound;
* Music;
* Next Scene.

Sem variables.

---

# 96. ROADMAP

PHASE 0:
Architecture
Schemas
Documentation
Agent structure

PHASE 1:
Astralis Core

PHASE 2:
Duel Engine

PHASE 3:
Effect Engine

PHASE 4:
Fusion Engine

PHASE 5:
Campaign Runtime

PHASE 6:
Astralis Studio Foundation

PHASE 7:
Card / Duelist / Deck / Fusion Editors

PHASE 8:
Effect Builder

PHASE 9:
Campaign Editor

PHASE 10:
Basic Project Play / Preview

PHASE 11:
Test Lab

PHASE 12:
Advanced Preview

* Scene Preview
* Duel Preview
* Effect Preview
* Fusion Preview

PHASE 13:
Debug / State Inspector / Trace / State Diff

PHASE 14:
Packaging / Distribution

PHASE 15:
Polish

---

# 97. PREVIEW ROADMAP PRINCIPLE

Não implementar Preview Effect cedo apenas porque é visualmente impressionante.

Preview avançado depende de:

* GameState estável;
* EffectSystem estável;
* DuelSystem estável;
* Data Contract estável;
* Astralis executável estável;
* Astralis Studio communication estável.

Portanto:
Preview avançado é fase posterior.

---

# 98. TEST LAB ROADMAP PRINCIPLE

A infraestrutura de Test Lab deve ser prevista arquiteturalmente cedo.

Porém a UI completa pode ser implementada depois.

Desde o início:

* GameState deve permitir setup controlado;
* runtime deve permitir observabilidade;
* sistemas devem ser testáveis;
* eventos devem ser rastreáveis.

Não deixar Test Lab exigir reescrita completa do runtime.

---

# 99. DEBUG / TEST / PREVIEW REUSE

As três funcionalidades devem compartilhar infraestrutura:

```text
GameState
EventBus
State Snapshot
Runtime systems
Data loader
Asset loader
```

Mas possuem objetivos diferentes:

PLAY:
jogar.

PREVIEW:
experimentar.

TEST:
verificar.

DEBUG:
diagnosticar.

---

# 100. ANTI-OVERENGINEERING

Antes de adicionar uma abstração:

1. É necessária agora?
2. Resolve requisito concreto?
3. Reduz complexidade?
4. Preserva especialização do Astralis?
5. Pode ser testada?

Se não:
não adicionar.

Evitar:

* scripting engine;
* plugin architecture;
* generic game engine;
* excessive dependency injection;
* complex ECS sem necessidade;
* universal UI framework;
* custom programming language prematura.

---

# 101. NO-CODE PRINCIPLE

Astralis Studio deve permitir criar conteúdo através de:

* forms;
* selectors;
* blocks;
* graphs;
* drag-and-drop;
* properties;
* previews.

O usuário final NÃO deve precisar escrever código.

O fato de Project Data eventualmente ser JSON/etc. é detalhe interno.

---

# 102. FUTURE EXTENSIONS

Possíveis recursos futuros:

* variables;
* advanced conditional campaign;
* advanced Effect Flow;
* AI profiles;
* richer animation;
* more flexible UI parameters;
* advanced Test Lab;
* automatic test generation;
* recording tests;
* state breakpoints;
* richer state inspector;
* plugin ecosystem, somente se necessário;
* migration tools.

Nenhum é obrigatório para V1.

---

# 103. CORE SUCCESS CRITERIA

Arquitetura é bem-sucedida quando:

1. nova carta não exige alteração de código;
2. novo duelista não exige alteração de código;
3. novo deck não exige alteração de código;
4. nova fusão não exige alteração de código;
5. novo efeito suportado não exige programação do usuário;
6. nova cena não exige alteração de código;
7. nova campanha não exige alteração de código;
8. Astralis carrega Project Data externo;
9. Astralis Studio não implementa gameplay;
10. Preview usa Astralis;
11. Test Lab usa Astralis;
12. GUT testa internals;
13. editor e runtime usam contrato compatível;
14. projeto pode evoluir sem depender da instalação do Godot pelo usuário.

---

# 104. PRODUCT EXPERIENCE

Usuário final deve experimentar:

```text
Instala Astralis Studio
    |
    v
New Project
    |
    v
Create Cards
    |
    v
Create Duelists
    |
    v
Create Decks
    |
    v
Create Fusion Recipes
    |
    v
Create Effects
    |
    v
Create Campaign
    |
    v
Validate
    |
    v
Play / Preview
    |
    v
Export / Package
```

O usuário não precisa saber:

* Godot;
* GDScript;
* Rust;
* Tauri;
* Svelte;
* MCP;
* GUT.

---

# 105. DEVELOPMENT EXPERIENCE

A equipe/IA trabalha assim:

```text
USER
    |
    v
SPECIFICATION
    |
    v
LEAD ARCHITECT
    |
    +---- Systems/Data
    |
    +---- Runtime
    |
    +---- Campaign
    |
    +---- Editor
    |
    +---- QA
```

OpenCode é utilizado como ambiente/agent tooling.

Godot MCP é utilizado quando a IA precisa operar Godot.

GUT é utilizado para testar Astralis.

---

# 106. ASTRALIS AS SOURCE OF GAMEPLAY TRUTH

Toda afirmação relacionada a gameplay deve ser determinada por Astralis.

Exemplos:

"Esta carta pode atacar?"
Astralis decide.

"Qual é o dano?"
Astralis decide.

"Qual alvo foi selecionado?"
Astralis decide.

"Qual fusão aconteceu?"
Astralis decide.

"O efeito foi executado?"
Astralis decide.

"Qual cena vem depois?"
Astralis decide.

Astralis Studio apenas apresenta/edita os dados que levam a essas decisões.

---

# 107. ASTRALIS STUDIO AS SOURCE OF AUTHORING TRUTH

Toda autoria de conteúdo deve ser feita através do Astralis Studio.

Exemplos:

"Qual ATK da carta?"
Studio edita.

"Qual arte?"
Studio edita.

"Qual deck?"
Studio edita.

"Qual fusão?"
Studio edita.

"Qual diálogo?"
Studio edita.

"Qual caminho da campanha?"
Studio edita.

"Qual composição do efeito?"
Studio edita.

---

# 108. FINAL ARCHITECTURAL MODEL

```text
                  DEVELOPMENT
                  ============

       OpenCode
          |
          +--------------------+
          |                    |
          v                    v
     Godot MCP               GUT
          |                    |
          v                    v
       Godot               Astralis Tests
          |
          v
      ASTRALIS
          |
          v
     compiled build


                  PRODUCT
                  =======

+---------------------------+
|      ASTRALIS STUDIO      |
|                           |
| Project Authoring         |
| Card Editor               |
| Duelist Editor            |
| Deck Editor               |
| Fusion Editor             |
| Effect Builder            |
| Campaign Editor           |
| Validation                |
| Preview                   |
| Test Lab                  |
+-------------+-------------+
              |
              | Project Data
              v
+---------------------------+
|         ASTRALIS          |
|                           |
| Runtime                   |
| Duel Engine               |
| Effect Engine             |
| Fusion Engine             |
| Campaign Engine           |
| AI                        |
| Save System               |
| UI                        |
+---------------------------+
              |
              v
             GAME
```

---

# 109. FINAL PRINCIPLES

PRINCIPLE 01:
Astralis = runtime.

PRINCIPLE 02:
Astralis Studio = editor.

PRINCIPLE 03:
Godot = development technology, not user requirement.

PRINCIPLE 04:
Godot MCP = development tool for AI.

PRINCIPLE 05:
GUT = development/test tool.

PRINCIPLE 06:
OpenCode = development/AI tooling.

PRINCIPLE 07:
Astralis is source of gameplay truth.

PRINCIPLE 08:
Astralis Studio is source of authoring operations.

PRINCIPLE 09:
Schemas are the contract.

PRINCIPLE 10:
Data is separate from logic.

PRINCIPLE 11:
No individual card/duelist scripts.

PRINCIPLE 12:
Effects are declarative.

PRINCIPLE 13:
Runtime rules are fixed.

PRINCIPLE 14:
Runtime-supported content is configurable.

PRINCIPLE 15:
Campaign is a graph of scenes.

PRINCIPLE 16:
Campaign scenes contain ordered content.

PRINCIPLE 17:
Variables are postponed.

PRINCIPLE 18:
UI is specialized and limited.

PRINCIPLE 19:
Preview uses Astralis.

PRINCIPLE 20:
Test Lab uses Astralis.

PRINCIPLE 21:
Editor never owns gameplay implementation.

PRINCIPLE 22:
There must never be two gameplay engines.

PRINCIPLE 23:
Preview and Test Lab are different features.

PRINCIPLE 24:
Preview is for experimentation.

PRINCIPLE 25:
Test Lab is for verification.

PRINCIPLE 26:
GUT is for internal code testing.

PRINCIPLE 27:
Advanced Preview comes after core runtime/editor stability.

PRINCIPLE 28:
Few specialized agents are preferred over many micro-agents.

PRINCIPLE 29:
Power comes from composition, not arbitrary scripting.

PRINCIPLE 30:
Limitations are intentional product design.

---

# 110. FINAL PRODUCT DEFINITION

ASTRALIS:

"Runtime 2D especializado em duelo de cartas + campanha visual novel, capaz de interpretar projetos autorados pelo Astralis Studio."

ASTRALIS STUDIO:

"Editor visual especializado que permite criar projetos Astralis através de dados, blocos, graphs e propriedades, sem exigir programação."

THE PRODUCT IS NOT A GENERIC GAME ENGINE.

THE PRODUCT IS NOT A GENERIC TCG ENGINE.

THE PRODUCT IS A SPECIALIZED AUTHORING PLATFORM AROUND A FIXED RUNTIME MODEL.

PRIMARY GOAL:

Permitir que alguém crie:

"seu próprio jogo no estilo Forbidden Memories, com suas próprias cartas, duelistas, decks, fusões, efeitos, cenas, campanhas, imagens, músicas e história"

sem precisar alterar o código do Astralis.

FINAL ARCHITECTURAL RULE:

"Se Astralis sabe fazer, Astralis Studio deve poder permitir que o usuário configure."

"Se Astralis não sabe fazer, Astralis Studio não deve fingir que sabe."

"Quando uma nova capacidade for necessária, ela deve primeiro ser adicionada ao Astralis; somente depois deve ser exposta pelo Astralis Studio."

END OF MASTER SPECIFICATION

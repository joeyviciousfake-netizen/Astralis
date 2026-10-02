# 11 — MVP E ROADMAP


## 11.1 MVP

Runtime: carregar projeto/cartas/duelistas/decks, duelo, turn/summon/attack/damage, victory/defeat, fusion (receita + regra genérica, D08), effect inicial, save/load.
Efeito MVP: triggers `card_summoned/destroyed, turn_started/finished, attack_started, damage_dealt`; actions `modify_attack/defense, damage, heal, destroy, draw, discard`; targets `self, ally/enemy_monster, all_ally/enemy_monsters`.
Editor primeiro: Project/Card/Duelist/Deck/Fusion/Effect/Validation. Depois: Campaign/Preview/Test Lab mínimo. Preview avançado não é prioridade inicial.
Campanha MVP: Scene/Dialogue/Character/Background/Choice/Battle(win/lose)/Transition/Wait/Sound/Music/Next + flags-lite V1.2. Sem variables completas.

## 11.2 Roadmap

1 Astralis Core 2 Duel 3 Effect 4 Fusion 5 Campaign Runtime
6 Studio Foundation 7 Card/Duelist/Deck/Fusion 8 Effect Builder (+templates, +Testar agora) 9 Campaign Editor
10 Basic Play + Starter Kit 11 Test Lab mínimo 12 Preview avançado (só contexts de `Jogar a partir daqui`) 13 Inspector/Trace/Diff 14 Packaging/Exportação protegida v1.3 (player + .astralis + cadeado, android import V1 / fundido V2) 15 Polish

Princípios: preview avançado só após GameState/Effect/Duel/contrato/comunicação estáveis. Test Lab prever observabilidade cedo (setup controlado, eventos rastreáveis, seed) sem exigir reescrita.

Futuro (não V1): variables completas, campanha condicional avançada, flow avançado, AI profiles completos, animação rica, UI flexível, test generation/recording, breakpoints, inspector rico, plugins se necessário, migration.
ADIADOS FM (ordem do usuário, não esquecer): traps/equips/magicas/rituais (depois do editor certo), Exodia, contadores de rank, guardiã/terreno ±500, Swords/timers, IA avançada (a atual é fiel básica: kill fraco + best-margin).

## 11.3 Donos por pasta

`docs/ -> Lead Architect` · `astralis/ -> Runtime Engineer` · `schemas/ + data-model/ -> Systems/Data Engineer` · `campaign/ -> Campaign Engineer` · `astralis-studio/ -> Editor Engineer` · `tests/ + tools/ + ci/ -> QA/Integration`. Mudança compartilhada (schema, protocolo, formato `.astralis`) é coordenada: quem mexe no contrato avisa os outros donos antes.

Limite: nunca quebrar o trabalho por unidade de conteúdo. Não criar um dono novo para resolver uma carta, um duelista ou uma cena específica.

## 11.4 Como uma feature nova entra

1. comportamento 2. impacto 3. contrato 4. Astralis 5. Studio 6. testes 7. integra 8. documenta.

**Nunca começar pela UI se o runtime não tem a capacidade** (R4). Exemplo de uma Action nova: Systems faz o schema, Runtime executa, Editor faz o bloco/validação/descrição, QA faz o GUT, Architect confere as boundaries.

Regras de execução: ler o spec do domínio, respeitar invariantes, não inventar requisito, não ampliar escopo, não duplicar lógica, adicionar testes, atualizar docs, mudanças pequenas, compatibilidade.

Dev loop: `USER -> SPEC -> implementacao` via OpenCode; Coding-Solo godot-mcp (server `godot`, headless, Godot 4.7.2) para operar Godot; GUT 9.7.1 (`astralis/testing/`) para testar Astralis.

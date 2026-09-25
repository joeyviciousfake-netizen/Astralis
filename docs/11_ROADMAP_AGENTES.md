# 11 — MVP, ROADMAP E AGENTES

ORIGEM: spec v1.1 seções 80-91, 96, 102, 103, 105

## 11.1 MVP

Runtime: carregar projeto/cartas/duelistas/decks, duelo, turn/summon/attack/damage, victory/defeat, fusion (receita+regra V1.2), effect inicial, save/load.
Efeito MVP: triggers `card_summoned/destroyed, turn_started/finished, attack_started, damage_dealt`; actions `modify_attack/defense, damage, heal, destroy, draw, discard`; targets `self, ally/enemy_monster, all_ally/enemy_monsters`.
Editor primeiro: Project/Card/Duelist/Deck/Fusion/Effect/Validation. Depois: Campaign/Preview/Test Lab mínimo. Preview avançado não é prioridade inicial.
Campanha MVP: Scene/Dialogue/Character/Background/Choice/Battle(win/lose V1.2)/Transition/Wait/Sound/Music/Next + flags-lite V1.2. Sem variables completas.

## 11.2 Roadmap

0 Architecture/Schemas/Docs/Agentes
1 Astralis Core 2 Duel 3 Effect 4 Fusion 5 Campaign Runtime
6 Studio Foundation 7 Card/Duelist/Deck/Fusion 8 Effect Builder (+templates, +Testar agora) 9 Campaign Editor
10 Basic Play + Starter Kit 11 Test Lab mínimo 12 Preview avançado (só contexts de `Jogar a partir daqui`) 13 Inspector/Trace/Diff 14 Packaging/Exportação protegida v1.3 (player + .astralis + cadeado, android import V1 / fundido V2) 15 Polish

Princípios: preview avançado só após GameState/Effect/Duel/contrato/comunicação estáveis. Test Lab prever observabilidade cedo (setup controlado, eventos rastreáveis, seed) sem exigir reescrita.

Futuro (não V1): variables completas, campanha condicional avançada, flow avançado, AI profiles completos, animação rica, UI flexível, test generation/recording, breakpoints, inspector rico, plugins se necessário, migration.
ADIADOS FM (ordem do usuário, não esquecer): traps/equips/magicas/rituais (depois do editor certo), Exodia, contadores de rank, guardiã/terreno ±500, Swords/timers, IA avançada (a atual é fiel básica: kill fraco + best-margin).

## 11.3 Agentes (6, por domínio — travado em D13)

1 Lead Architect (arquitetura/contratos/invariantes/docs, impede hardcoding, editor-gameplay, genericização)
2 Runtime Engineer (Astralis, Duel/Effect/Fusion execution, AI, Save, UI, DataLoader, Preview/Test modes) — ponto de sobrecarga, ver split abaixo
3 Systems/Data Engineer (owner schemas, Card/Duelist/Deck/Fusion/Effect, serialização, formato .astralis)
4 Campaign Engineer (Campaign/SceneRunner/Dialogue/Choice/Timeline/Graph/Battle transition, respeita schema) — esvazia após MVP
5 Editor Engineer (Studio Rust/Tauri/Svelte, editores, Builder, Asset, Validation, Preview/Test UI, empacotamento zip, sem gameplay alternativo) — ponto de sobrecarga
6 QA/Integration (GUT, integração/regressão, Test Lab infra, compatibilidade player x fita, tamper, build)

Distribuição sem dono fixo na V1: força-tarefa Systems (formato) + Runtime (leitura/validação) + Editor (Exportar/zip/chave) + QA (matriz + tamper), Lead coordena. 7º agente Build/Release só se APK fundido V2 virar dor recorrente.

Limites de split (não criar micro-agentes sem atingir):
- Runtime lotar (duelo+efeito+fusão+IA) → especialista temporário de Efeito, rejunta depois.
- Editor lotar (7 telas) → especialista temporário de Campaign Editor, rejunta depois.
- Nunca dividir por carta/duelista/cena individual.

Ownership: `docs/architecture->Lead, astralis/->Runtime, schemas/data-model->Systems, campaign/->Campaign, astralis-studio/->Editor, tests/tools/ci->QA`. Shared changes coordenadas.

Regras: ler spec do domínio, respeitar invariantes, não inventar requisito, não ampliar escopo, não duplicar lógica, adicionar testes, atualizar docs, mudanças pequenas, compatibilidade.

Feature nova: 1.comportamento 2.impacto 3.contrato 4.Astralis 5.Studio 6.testes 7.integra 8.documenta. Nunca começar pela UI se runtime não tem capacidade. Ex. nova Action: Systems faz schema, Runtime executa, Editor faz bloco/validação/descrição, QA faz GUT+scenario, Architect checa boundaries.

Dev loop: USER->SPEC->LEAD->{Systems,Runtime,Campaign,Editor,QA} via OpenCode; Coding-Solo godot-mcp (server `godot`, headless, Godot 4.7.2) para operar Godot; GUT 9.7.1 (`astralis/testing/`) para testar Astralis.

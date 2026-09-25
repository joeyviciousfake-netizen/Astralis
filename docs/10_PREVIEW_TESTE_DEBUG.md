# 10 — PREVIEW, TEST LAB, DEBUG

ORIGEM: spec v1.1 seções 40-65, 97, 98, 99

> Resposta direta: testes no editor usam o mesmo código do Astralis. Studio monta dado de teste, Astralis executa com sistemas reais e devolve resultado. Por isso nunca dá "funcionou no editor mas não no jogo" — editor não tem motor próprio.

## 10.1 Preview vs Test Lab

Preview = "ver conteúdo funcionando" (experimentação visual/interativa).
Test Lab = "verificar automaticamente se está correto" (determinístico/repetível).
Ambos usam Astralis. Nenhum tem gameplay independente.

## 10.2 [MELHORIA V1.2] Preview unificado

Antes: 6 modos (Play, Scene, Duel, Effect, Fusion) como fases separadas. Agora: um mecanismo:

```text
Studio -> save Project Data -> launch Astralis with context
{project_path, scene_id?, duel_setup{player, opponent, decks, lp, field, hand}?, seed?}
-> Astralis loads + runs -> GameState
```

- V1: `Play Project` (jogar normal).
- V2+: `Jogar a partir daqui` (botão contextual em cena/carta/duelo/efeito/fusão que só preenche o context acima). Effect/Fusion Preview são só contexts de duelo preparado, usando mesmo EffectSystem/FusionSystem do jogo.
- Studio nunca calcula efeito; só prepara cenário e pede execução.
- **Campo de Testes (contrato fechado, execução pendente):** o context `field/hand` acima tem forma oficial no contrato — `duel_setup.test_state` (doc 04.6, schema `duel_setup.schema.json`): `my_hand[0-5]` + `p0/p1 monster/spell[5]` (`null` ou `{card_id + face_up? + attack_position?}`), tudo opcional, `turn_order` fixo em `first_p1`. O Studio monta esse DADO na tab Campo de Testes (mão + campo meu e do inimigo + Iniciar teste); o Astralis executa de verdade e o duelo começa sempre na MINHA fase da mão (D24). Até o runtime ler o campo, o setup com `test_state` sobe como duelo normal (sem fingir estado inicial).

## 10.3 Test Lab (usa Astralis real)

Modelo: `TEST: SETUP/GIVEN/WHEN/THEN`. Ex.: GIVEN enemy ATK 2000 WHEN summon Fire Warrior THEN ATK==1500. Usuário monta visual, sem código.

Setup inicializa GameState (LP, mão, campo, grave, deck, duelistas, fase, turno, cena). Actions pedem operações ao Astralis (summon, attack, activate, end turn, draw, fuse, advance scene, choose). Assertions comparam EXPECTED vs ACTUAL (`player_lp==4000, card_attack(X)==1500, fusion_result==...`). Studio não calcula, só compara.

Fluxo: `Studio Test Scenario -> Astralis TestHarness.create/inject/set/emit/execute/advance/capture -> Real Game Systems -> Assertions -> TestResult -> Studio`.

Regra do Harness: PROIBIDO `custom_damage/fusion/effect`. CORRETO `prepare_state() + call_real_*() + capture_result()`.

[MELHORIA V1.2] Test Lab mínimo na V1: botão `Testar agora` no Effect/Card/Fusion Editor com setup auto-sugerido (ex.: efeito precisa de inimigo -> cria Test Monster 2000 ATK) + seed fixa para determinismo (`seed=12345`, mesmo cenário = mesmo resultado). UI completa, trace rico, state diff completo, recording, breakpoints, campaign debugger (Play/Pause/Step) ficam pós-V1.

**Campo de Testes (tab nova, contrato V1):** é o Test Lab mínimo com cara de mesa — monta `my_hand` + `p0/p1 monster/spell` (doc 04.6), clica Iniciar teste, e o duelo real começa sempre na MINHA fase da mão (`turn_order: first_p1`, fase da mão D24). Contrato: tudo opcional, mão máx 5, slots exatos 5+5 por lado, `face_up?/attack_position?` ausentes = `true`. Validação em PT-BR no Studio (`checar_test_state`); execução no runtime (ler `test_state` e posicionar antes do turno 1 — pendente, ver retorno do Systems ao Lead). O GIVEN/WHEN/THEN completo segue sem schema (só o context de campo+mão está contratado).

Falha mostra: expected, actual, trace real, state_before/after, events, erro — para debug humano e por IA.

## 10.4 Camadas e ferramentas

- L1 Project Validation: sem gameplay, checa schema/IDs/refs/assets/tipos.
- L2 Astralis Test Lab: gameplay real, checa effects/duel/fusion/campaign.
- L3 GUT (v9.7.1, testes em `astralis/testing/`, hoje 12 testes): código interno (DataLoader, Validation, GameState, Turn/Battle/Damage/Fusion/Effect, CampaignRunner, Save). Prioridade nesses sistemas.

GUT = dev-oriented ("EffectResolver processa X"). Test Lab = autor-oriented ("esta carta deveria destruir este monstro"). Complementares. Para sistemas críticos: SPEC->TEST->IMPLEMENT->RUN->FIX->REGRESSION; bug vira teste permanente.

Debug V1: State Inspector simples (scene, turn, LP, field, hand, grave, active effects, event queue). Adiado V1: State Diff completo, Trace rico, Breakpoints, Recording, DebugConsole completo. Infra (GameState, EventBus, Snapshot, Data/Asset loader) deve ser compartilhada desde cedo para não exigir reescrita.

## 10.5 [MELHORIA V1.5] Erro como gente + Testar agora em tudo + Play verde

Validação fala PT-BR simples, sem termo técnico: em vez de `target incompatível`, mostra `essa carta precisa de um inimigo no campo`. Todo erro mostra onde clicar para consertar; quando a correção é segura (ex.: preencher vida vazia com 8000, ligar on_lose esquecido), botão `Consertar pra mim`.

Botão `Testar agora` existe em todo editor (carta, efeito, fusão, duelo), não só no efeito: monta cenário pronto com seed fixa e mostra `eu esperava X, aconteceu Y, por quê?` com expected, actual e trace real. Botão `Criar teste permanente` salva o cenário.

Botão verde `Jogar` em todo editor: `Jogar a partir daqui` preenche o context (cena, duelo, carta, efeito, fusão) e lança o mesmo Astralis. V1 já inclui para carta/duelo/cena; efeito/fusão como contexto de duelo preparado.

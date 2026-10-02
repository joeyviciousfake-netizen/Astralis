# 10 — PREVIEW, TEST LAB, DEBUG


> Resposta direta: testes no editor usam o mesmo código do Astralis. Studio monta dado de teste, Astralis executa com sistemas reais e devolve resultado. Por isso nunca dá "funcionou no editor mas não no jogo" — editor não tem motor próprio.

## 10.1 Preview vs Test Lab

Preview = "ver conteúdo funcionando" (experimentação visual/interativa).
Test Lab = "verificar automaticamente se está correto" (determinístico/repetível).
Ambos usam Astralis. Nenhum tem gameplay independente.

## 10.2 Preview unificado

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

> **O que existe hoje é o Campo de Testes** (descrito no fim desta seção). O
> `TestHarness`, o cenário de teste, o botão `Testar agora` e o trace rico são
> **PLANO** e não têm linha de código. O que está escrito abaixo como modelo é o
> desenho do que seria, não o que é.

Modelo: `TEST: SETUP/GIVEN/WHEN/THEN`. Ex.: GIVEN enemy ATK 2000 WHEN summon Fire Warrior THEN ATK==1500. O usuário monta visual, sem código.

O setup inicializaria o `GameState` (LP, mão, campo, cemitério, baralho,
duelistas, fase, turno). As actions pediriam operações ao Astralis (summon,
attack, activate, end turn, draw, fuse). As assertions comparam EXPECTED vs
ACTUAL. O Studio não calcula, só compara.

A regra do harness, quando existir: **PROIBIDO** `custom_damage/fusion/effect`.
O certo é `prepare_state()` + chamar o sistema real + capturar o resultado. É a
mesma regra do R1 aplicada ao teste: sem duble, senão o teste prova o duble.

Falha mostra: expected, actual, trace, estado antes e depois, e o erro.

**Campo de Testes (tab Testes):** é o Test Lab mínimo com cara de mesa — monta
`my_hand` + `p0/p1 monster/spell` (doc 04.6), clica Iniciar teste, e o duelo real
começa sempre na MINHA fase da mão (`turn_order: first_p1`, fase da mão D24).
Contrato: tudo opcional, mão máx 5, slots exatos 5+5 por lado,
`face_up?/attack_position?` ausentes = `true`. Validação em PT-BR no Studio
(`checar_test_state` em `main.rs`) e **execução no runtime**
(`_aplicar_test_state` em `astralis/duel/duel_manager.gd`). O GIVEN/WHEN/THEN
completo segue sem schema (só o contexto de campo+mão está contratado).

O botão `Testar agora` com setup sugerido, e o Test Lab completo, são **PLANO**:
não existem. O que existe é o Campo de Testes e o botão verde Jogar.

## 10.4 Camadas e ferramentas

- L1 Project Validation: sem gameplay, checa schema/IDs/refs/assets/tipos.
- L2 Campo de Testes: gameplay real, com `test_state` — só o que o `duel_setup`
  já permite.
- L3 GUT (v9.7.1, em `astralis/testing/`): código interno (DataLoader,
  Validation, GameState, Turn/Battle/Damage/Fusion, a tela da mesa 3D, a IA
  rival e a carta). **Effect, Save e Campaign não têm motor**, então não há
  teste deles.

GUT = dev-oriented ("o `BattleSystem.can_attack` recusa no turno 1"). Campo de
Testes = autor-oriented ("esta carta deveria destruir este monstro"). São
complementares. Para sistemas críticos: SPEC→TEST→IMPLEMENT→RUN→FIX→REGRESSION;
**bug vira teste permanente**.

Debug V1: State Inspector simples (scene, turn, LP, field, hand, grave, active effects, event queue). Adiado V1: State Diff completo, Trace rico, Breakpoints, Recording, DebugConsole completo. Infra (GameState, EventBus, Snapshot, Data/Asset loader) deve ser compartilhada desde cedo para não exigir reescrita.

## 10.5 Erro como gente + Testar agora em tudo + Play verde

Validação fala PT-BR simples, sem termo técnico: em vez de `target incompatível`, mostra `essa carta precisa de um inimigo no campo`. Todo erro mostra onde clicar para consertar; quando a correção é segura (ex.: preencher vida vazia com 8000, ligar on_lose esquecido), botão `Consertar pra mim`.

Botão `Testar agora` existe em todo editor (carta, efeito, fusão, duelo), não só no efeito: monta cenário pronto com seed fixa e mostra `eu esperava X, aconteceu Y, por quê?` com expected, actual e trace real. Botão `Criar teste permanente` salva o cenário.

Botão verde `Jogar` em todo editor: `Jogar a partir daqui` preenche o context (cena, duelo, carta, efeito, fusão) e lança o mesmo Astralis. V1 já inclui para carta/duelo/cena; efeito/fusão como contexto de duelo preparado.

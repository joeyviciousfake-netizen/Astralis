# 08 — CAMPANHA (VISUAL NOVEL)

ORIGEM: spec v1.1 seções 31-36, 95

## 8.1 Modelo

Campanha é Visual Novel 2D data-driven. Usuário controla história, ordem, diálogos, personagens, backgrounds, escolhas, transições, batalhas, fluxo.

Duas visões:
- GRAPH: fluxo global (Scenes, branching, transitions, battle nodes).
- SCENE/TIMELINE: conteúdo ordenado dentro da cena.

```text
Scene A -> Dialogue -> Choice -> Scene B / Scene C -> Battle -> Scene D
```

Scene: `id, background, music, elements[]`.
Elements V1: `dialogue, character, image, choice, battle, transition, sound, music, wait, jump, next scene`. Sem variables completas na V1 (ver 8.3).

Timeline define o que acontece; Graph define para onde ir.

## 8.2 [MELHORIA V1.2] Battle Node com vitória/derrota

V1.1 citava `battle` mas sem saídas. Obrigatório na V1.2:

```text
BattleNode:
  duelist_id
  deck_override?
  on_win: -> scene_id
  on_lose: -> scene_id
  allow_retry: bool
  flags_on_win: [...]
  flags_on_lose: [...]
```

Sem isso campanha trava no primeiro Game Over. Studio mostra 2 setas coloridas no grafo. Astralis decide vencedor e faz o jump.

## 8.3 [MELHORIA V1.2] Flags-lite (em vez de zero variables)

V1.1 adiava tudo. Problema: Choice sem memória não permite progressão.

V1.2 permite só o mínimo, sem linguagem:

```text
flags: booleanas (ex.: venceu_kaiba, visitou_castelo)
counters: inteiros simples (ex.: vitorias: 0..99)
```

- Setadas por: vitória/derrota em BattleNode, escolha em ChoiceNode, visita de Scene.
- Usadas como: condição de desbloqueio de transição `requires_flag: venceu_kaiba` ou `requires_counter >= 3`.
- UI: checkbox + número. Sem expressão arbitrária, sem string vars, sem quests/inventory/reputation na V1.

Suficiente para finais múltiplos, revanche, caminho secreto. Variables completas (bool/int/string, conditions avançadas) ficam para futuro, após runtime/campanha/editor/preview estáveis.

Choices V1: `"Sim" -> scene_b / "Não" -> scene_c`, opcionalmente setando flag.

## 8.4 [MELHORIA V1.5] Campanha Simples/Avançado + modelos

Simples: 3 campanhas modelo duplicáveis (`Rival clássico: 2 cenas + 1 batalha | Torneio: fila de batalhas com revanche | Final múltiplo: 1 escolha + 2 finais via flag`). Cena modelo já vem com batalha win/lose ligada e flags exemplo. Avançado: grafo + timeline completos. Mesmos schemas, mesma execução no Astralis.

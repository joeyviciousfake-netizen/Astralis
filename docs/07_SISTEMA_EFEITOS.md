# 07 — SISTEMA DE EFEITOS

ORIGEM: spec v1.1 seções 20-30, 93

## 7.1 Modelo

Efeito permite liberdade dentro do que Astralis suporta. Usuário combina blocos declarativos, não programa:

```text
TRIGGER -> CONDITIONS -> TARGET -> ACTIONS -> FLOW
```

Uma carta pode ter múltiplos efeitos. Texto humano é derivado, não fonte da lógica. Ex.:
dados `trigger=card_summoned, target=enemy_monster, action=modify_attack -500 até fim do turno`
-> "Quando invocada, reduza o ATK de 1 monstro do oponente em 500 até o fim do turno."

## 7.2 Vocabulário V1

Triggers MVP: `card_summoned, card_destroyed, turn_started, turn_finished, attack_started, damage_dealt`.
Lista completa futura inclui `attack_finished, damage_received, card_drawn, card_sent_to_graveyard, fusion_performed, card_equipped`, etc. Regra: Studio só mostra trigger que Astralis sabe executar.

Conditions ex.: `attack >/ < value, defense >/ <, attribute == X, monster_type == X, card_in_field/hand/graveyard, player_lp > X, opponent_lp < X, exists_card(X)`.
Targets ex.: `self, ally_monster, enemy_monster, all_ally/enemy_monsters, random/selected_card, card_in_graveyard/hand`. Targets têm compatibilidade declarada com Actions.
Actions MVP: `modify_attack, modify_defense, damage, heal, destroy, draw, discard`. Futuro: `summon, change_position/attribute/type, equip, add_to_hand, remove_from_field`.
Flow V1: `multiple actions + sequence`. Condicional `if/else/repeat/stop` só após base estável. Não virar linguagem geral.

Nova Action exige: 1.schema 2.runtime 3.editor UI 4.validação 5.testes 6.docs.

## 7.3 Níveis de complexidade

L1: Trigger->Action. L2: +Condition+Target. L3: +Conditions+Targets+Multiple Actions+Flow. Astralis tem modelo unificado; Studio esconde complexidade.

Builder é contextual: `modify_attack` mostra target/value/duration; `draw` mostra amount; `destroy` mostra target. Sem campos irrelevantes.

Validação: Studio faz UX, Astralis valida ao carregar/executar. Estados VALID/WARNING/ERROR. ERROR ex.: trigger/action inexistente, target incompatível, campo ausente, ref inexistente. Nunca erro crítico silencioso.

## 7.4 [MELHORIA V1.2] Effect Templates (Modo Simples)

Problema: montar TRIGGER->... do zero assusta. Solução sem mudar motor:

- Modo Simples: galeria de modelos: `[Dano ao invocar] [Enfraquecer inimigo] [Comprar carta] [Destruir ao morrer]`. Usuário escolhe, preenche 2-3 campos, Studio gera o bloco declarativo padrão.
- Modo Avançado: edita blocos completos.

Mesmo schema, mesma validação, mesma execução. Template é só atalho de autoria. Smart Test Setup sugere cenário a partir do template (ex.: precisa de inimigo com 2000 ATK), mas resultado sempre vem do Astralis.

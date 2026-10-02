# 07 — SISTEMA DE EFEITOS

> **O que existe:** o contrato (`schemas/effect.schema.json`), a validação no
> Studio e a galeria de 4 modelos.
> **O que não existe:** o motor. Não há `EffectSystem` nem `EffectResolver` em
> `astralis/`, e a mesa **não executa** efeito (D30). Ativar magia na zona avisa.
> O editor mostra o aviso fixo "execução vem depois" e **não** tem botão de Play.
>
> Isto é o contrato e o desenho. O vocabulário abaixo é o que está no schema —
> se divergirem, vale o schema.

## 7.1 O MODELO

```text
TRIGGER -> CONDITIONS -> TARGET -> ACTIONS -> FLOW
```

O **texto humano é derivado**, nunca a fonte da lógica. O campo `description` é
só exibição: trocar o texto não muda o que o efeito faz, e mudar o dado não exige
reescrever a frase.

## 7.2 O VOCABULÁRIO (é o `enum` do schema, fechado)

**Triggers (6):** `card_summoned`, `card_destroyed`, `turn_started`,
`turn_finished`, `attack_started`, `damage_dealt`.

**Targets (11):** `self`, `self_player`, `opponent`, `ally_monster`,
`enemy_monster`, `all_ally_monsters`, `all_enemy_monsters`, `selected_card`,
`random_card`, `card_in_graveyard`, `card_in_hand`.

`self_player` e `opponent` são os alvos de LP, e são **obrigatórios** para
`damage` e `heal`. `draw` tem que mirar `self_player`.

**Conditions:** `field` + `operator` + `value`. Os `field` que o Studio oferece
são `opponent_monster_attack`, `player_lp`, `opponent_lp`, `attribute` e
`monster_type`. O **schema não fecha esse conjunto** (`field` é string livre),
porque nenhuma condição está implementada ainda — fechar a lista agora seria
travar o contrato sem base.

Os operadores são `>`, `<`, `>=`, `<=`, `==` e `!=`.

**Actions:** `damage`, `heal`, `destroy`, `draw`, `discard`,
`modify_attack`, `modify_defense`.

**Flow V1:** `mode` só aceita `"sequence"`, e `actions` é uma lista executada em
ordem. `if`/`else`/`repeat` só depois da base, para o flow não virar linguagem
geral (R3).

## 7.3 A REGRA QUE NÃO PODE QUEBRAR

**O Studio só mostra o que o Astralis executa.**

Enquanto não houver motor, isso significa duas coisas concretas:

1. O Studio **não** calcula efeito. Ele monta o bloco, valida contra o schema e
   salva.
2. O botão de **Play/Testar** **não pode existir** no editor de efeitos. Ele já
   traz um aviso fixo no lugar, e o aviso é a implementação da regra.

Uma `Action` nova só existe depois de passar por tudo: **1.** o schema,
**2.** o runtime que a executa, **3.** a UI do editor, **4.** a validação,
**5.** o teste, **6.** o doc. Começar pela UI é o caminho que produz "funciona no
editor e não no jogo".

## 7.4 SIMPLES E AVANÇADO

O **Modo Simples** é a galeria de 4 modelos — `Dano ao invocar`, `Enfraquecer
inimigo`, `Comprar carta`, `Destruir ao morrer`. O usuário escolhe o modelo,
preenche 2-3 campos, e o Studio **gera o bloco** do Modo Avançado a partir dele.

O template é **atalho de autoria**, não um tipo separado: o resultado é o mesmo
`Effect` do schema, validado pelo mesmo caminho. Por isso os dois modos não
divergem.

## 7.5 O QUE FALTA PARA EXISTIR

| Falta | Quem faz |
|---|---|
| `EffectSystem` que resolve `TRIGGER→...` durante o duelo | Runtime |
| os `field` de condition fechados no schema | Systems |
| `if`/`else`/`repeat` no `flow` | Systems + Runtime |
| a botón de Testar no editor | Editor, **depois** do motor |
| GUT do resolver, com o Astralis real | QA |

O **`effects.json` nasce vazio** e isso é o estado normal. Sem efeitos cadastrados
o gate dá **aviso** (diz onde cadastrar); com efeitos cadastrados e um id fora
do catálogo, dá **erro**.

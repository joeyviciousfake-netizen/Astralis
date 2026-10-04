# 13 — TABULEIRO E DUELO

> As regras do duelo: as 6 zonas, as 4 fases, a mão, o LP, a vitória, o contrato
> de `duel_setup` e a arena. As regras aqui são D15, D17, D18, D26, D27, D42, D43,
> D49 e D50; o porquê de cada uma está no `DECISOES.md` e não se repete.

## 13.1 ZONAS (V1, fechadas)

| Zona | Aceita |
|---|---|
| `deck` | 20 a 60 cartas (`schemas/deck.schema.json`) |
| `monster_zone` | 5 slots, `p{lado}_m0..4` |
| `spell_zone` | 5 slots, `p{lado}_s0..4` |
| `graveyard` | lista, sem teto |
| `banished` | lista, sem teto |

São 5+5 por lado, e o schema da arena exige os 20 slots com o padrão
`^(p0|p1)_(m|s)[0-4]$`. Nenhum número de zona mora em `game_state.gd`: cada
sistema usa o seu literal no ponto da regra (`turn_manager.gd` usa 5 e 7).

## 13.2 FASES DO TURNO (nesta ordem, fixa)

`DRAW → MAIN → BATTLE → END`

A ordem é **lógica**, e a barra da tela mostra a fase real do motor. Mostrar as
mesas da referência seria inventar mecânica que o duelo não tem.

## 13.3 MÃO

- 5 cartas no início, **sem extra**.
- **Refill até 5** no começo do turno, para os dois lados.
- Acima de 5 fica de fora; o descarte tem teto 7.
- **Completar o baralho é derrota na hora.**
- A mão é sempre centralizada no X do centro do campo.
- A mão do rival **nunca mostra a frente**.

## 13.4 LP

- O valor é sempre o do `duel_setup`; o do duelista é sugestão do Studio (D21).
- Teto 1 a 99999 (`exclusiveMinimum: 0`, `maximum: 99999` no schema).
- Sem valor no setup, o padrão é 4000.
- **O Studio nunca calcula dano.** Ele monta o dado e o jogo responde.

### 13.4.1 SEMENTE (`duel_setup.seed`, D42)

| `seed` | Significado |
|---|---|
| `0` ou ausente | **sem semente** — sorteio de verdade a cada partida |
| diferente de 0 | semente fixa — determinismo para Test Lab e testes |

Quem começa é **dado do motor** (`turn_order`), nunca um valor guardado na tela
(R3). A tela honra o `current_player` do motor inclusive quando o rival começa, e
conduz o turno dele pelo mesmo caminho real da jogada do jogador.

## 13.5 VITÓRIA E DERROTA

- `LP <= 0` perde.
- Comprar com o baralho vazio perde (deckout).
- O Campo de Testes (com `test_state`) libera o ataque no turno 1; no duelo
  normal **ninguém** ataca enquanto o contador de turno for 1 (D43). A trava é
  pelo **contador**, não pelo lado: quem começou a partida joga o turno 1 inteiro
  e, quando a vez passa, o outro já entra no turno 2.

## 13.6 FIXO vs DADO

| FIXO (lógica, no código) | DADO (o autor mexe) |
|---|---|
| 5+5 slots por lado | quem é o duelista e o deck dele |
| fases `DRAW/MAIN/BATTLE/END` | o LP inicial |
| mão 5, refill até 5 | o conteúdo do baralho |
| virar de costas desvira ao ser atacada | as receitas de fusão |
| passo da fase da mão, menu da estrela | a arte, a moldura, a descrição |
| a trava do turno 1 | `turn_order` e `seed` |
| o dogo da IA escolher e a mesa executar | os parâmetros de `ai_preset` |

"Existe LP" é regra. "Começar com 8000" é dado.

## 13.7 CONTRATO `duel_setup`

```json
{
  "player": "fm_duelist_01",
  "opponent": "fm_duelist_02",
  "decks": { "p0": "fm_deck_01", "p1": "fm_deck_02" },
  "starting_lp": 8000,
  "turn_order": "first_p1",
  "seed": 0,
  "test_state": null
}
```

Validações que importam: `decks.p0` e `decks.p1` precisam existir e apontar para
um duelista com aquele deck; `starting_lp` é inteiro positivo até 99999;
`turn_order` só aceita `first_p1`, `first_p2`, `random` ou `moeda`; `seed` é
inteiro. `random` e `moeda` são **o mesmo sorteio** no motor — a diferença é que
`moeda` faz a tela MOSTRAR o sorteio (o desenho em `moeda_3d.gd`, doc 15 secao
15.10); `moeda` com `test_state` é `first_p1`.

`turn_order` também decide se a tela tem **ESPERA**: existe moeda na tela quando o
dado é `moeda`, e é daí que vem o painel em branco e a navegação travada (D80,
doc 15 secao 15.10). Sem `moeda` não há espera — não há o que esconder.

O duelo **DEV** (o que o editor abre sem `--project`) é sempre `moeda`: o sorteio
na tela é o assunto que se está olhando, e um sorteio que só sai em uma partida de
três é sorteio que quase ninguém vê. As outras duas ordens continuam alcançáveis
pelo setup de um projeto e pelo Studio. O headless (GUT/CI) **não** usa o duelo DEV
— ele cai no `schemas/examples`, e é por isso que a seed fixa dos testes continua
dando o mesmo primeiro jogador.

**`test_state`** (V1, opcional, D33) é o estado inicial do Campo de Testes:
`my_hand` de 0 a 5 cartas, e 4 zonas de 5 slots (`p0/p1_monster`, `p0/p1_spell`),
onde cada slot é `null` ou `{card_id, face_up?, attack_position?}`. Ausente de
`face_up` ou `attack_position` significa `true`. Tudo opcional: a ausência do
campo é um duelo normal. Quando presente, `turn_order` é `first_p1` (o schema
exige com `if/then`).

O runtime **aplica** o `test_state` em `duel_manager.gd` (`_aplicar_test_state`).

## 13.8 O STUDIO NUNCA CALCULA

Ele monta o `duel_setup` e lança o jogo. Quem decide invocação, ataque, dano,
fusão, vitória e derrota é o runtime (R1, R2). O botão "Testar fusão" do Studio
**não executa jogo**: ele confere o dado e diz que validou sem jogar.

## 13.9 SLOTS

Cada slot tem **ID fixo** (`p0/p1` + `m`/`s` + índice). A lógica só usa o ID; a
posição sai do arquivo da arena. Mover um slot não pode quebrar regra (D17).

## 13.10 A ARENA

**A arena é do jogo, e tem um dono só** (D50).

- O arquivo oficial é `schemas/examples/arenas/arena_starter.json`, com os 20
  slots e o bloco `hand`.
- `astralis/core/board_layout.gd` **não tem constante de grade**. `default_pos` e
  `default_layout` devolvem nulo, e quem chama decide o que fazer.
- O `arena_id` do `duel_setup` é lido e **ignorado**; a lista de arenas do Studio
  é fixa em `arena_starter`.
- Uma pasta `arenas/` num projeto é **ignorada com aviso**: um projeto não tem
  mesa própria.
- Arquivo faltando ou quebrado é **erro honesto** — `valida_arena_oficial`
  lista o que falta, o log avisa e a mesa **não desenha o campo**. Não existe mais
  para onde cair, então inventar uma mesa seria pior do que não ter nenhuma.

**Os números (medidos do arquivo, e o portão é o GUT):**

| Eixo | Valor |
|---|---|
| X dos 5 slots de monstro | `632 / 895 / 1158 / 1421 / 1684` — passo **263** |
| Y da fileira de monstro do jogador | `695` |
| Y da fileira de magia do jogador | `958` |
| Y da fileira de monstro do rival | `305` |
| Y da fileira de magia do rival | `42` |
| mão do jogador | `x 1240`, `y 980`, `step 95` |
| mão do rival | `x 1240`, `y 20`, `step 60` |

**A grade é um valor só: 263, nas SEIS direções** (D49) — o passo horizontal das
4 fileiras **e** o vão vertical monstro→magia dos dois lados. A distância entre as
duas fileiras de monstro é **390 e fica congelada**, porque mudar isso desalinha o
campo que o usuário aprovou.

Se o vão ficar feio, o que se muda é o **JSON**, nunca um número escondido no
código.

**A medida da grade é em unidades de mundo, por código, nunca em pixel de foto.**
A volta da mesa (D47) faz o mesmo intervalo de mundo aparecer com 276, 257 e 220
px na tela — é proporção, não erro, e a lente não pode ser mexida (D41).

## 13.11 DE ONDE OS DADOS VÊM

- O jogo em produção lê o projeto por `--project` e, por cima, `--setup`.
- `schemas/examples/` é **dado de teste**, nunca de produção.
- `astralis-studio/projects/default/` é o projeto do editor: abre vazio e é
  populado só por Importar (D29).

# 13 — TABULEIRO E DUELO V1

ORIGEM: desdobramento de `05_RUNTIME_DUELO.md` + contrato `04_CONTRATO_DADOS.md`
STATUS: AUTHORITATIVE V1 (decisão Lead 2026-09-23, insumos runtime+systems)
OWNER: lead (lógica runtime-owned, contrato systems-owned)

## 13.1 Zonas fixas V1

Runtime fixa nomes, tamanhos e o que cada zona aceita. Dado só define conteúdo.

```text
deck: pilha, 20-60 cartas (ver 13.7), só Card IDs. Compra do topo.
hand: mão do jogador. Ver 13.3.
monster_zone[5]: até 5 monstros em campo.
spell_zone[5]: até 5 magias/armadilhas em campo.
graveyard: pilha de destruídos/usados.
banished: pilha simples de removidos.
```

> 5+5 por lado (não 3+3): decisão D15/D17, já o que o schema (`arena.schema.json` exige 20 slots, `minItems`/`maxItems` 20, pattern `^(p0|p1)_(m|s)[0-4]$`) e o runtime (`game_state.gd` `MONSTER_SLOTS=5`, `SPELL_SLOTS=5`) usam. A versão 3+3 deste texto era o resquício de 2026-09-23.

Sem zona fusão V1: fusão consome mão+campo e entrega no campo.
Sem Extra Deck V1 (adiado por R5).

## 13.2 Fases do turno V1 (fixas, nesta ordem)

```text
DRAW → MAIN → BATTLE → END
```

- DRAW: completa a mão até 5 (ver 13.3).
- MAIN: 1 invocação normal (ou 1 fusão, que conta como a mesma jogada), magias, posicionar.
- BATTLE: 1 ataque por monstro; alternar ATK/DEF aqui.
- END: descarta o excesso da mão, checa vitória/derrota.

`standby / main2` adiados. Ordem e permissões são LOGIC fixa.

**Sem ataque no turno 1 (D43, vale para quem estiver jogando).**
O contador de turno manda: enquanto for `turn 1` — ou seja, quem começou a
partida — **ninguém ataca**. Assim que a vez passa, o outro lado já entra no
`turn 2` e ataca normalmente. A trava **não é por jogador**, é pelo número do
turno. Antes ela somava "só o lado 0" (D15), e por isso o rival começando
atacava de cara. Exceção: Campo de Testes com `test_state` (`is_test`, D34)
libera o ataque no turno 1, como antes.

## 13.3 Mão V1 (regra universal, fixa)

- Inicial: **5 cartas**, sem carta extra dos dois lados (D26). Ninguém compra no turno 1.
- A cada compra: **completa a mão até 5** para o jogador da vez (D26, regra do FM fiel). Quem já tem 5+ não compra nem perde carta.
- Descarte: quando a mão passa de **7** (só avaliado no fim da fase do jogador), o excesso vai para o cemitério.
- Deck out: tentar completar a mão 5 com o deck vazio **perde na hora** (D26). Ter 5+ com o deck vazio NÃO perde — só perde quando precisa de carta.
- `hand_size / max_hand` NÃO vão no JSON V1 (fixos, reduz matriz de teste).

## 13.4 LP V1

- FIXO: existe LP, fórmula dano/cura, LP nunca passa do inicial, checagem após dano + no fim do turno.
- DADO: `starting_lp` por duelo (padrão do FM 8000; o projeto novo pode usar 4000). Teto do contrato: **1 a 99999** (`duel_setup.schema.json`), e é o que o Studio recusa. Se o valor vier vazio/<=0, o runtime usa 4000.
- `duelist.starting_lp` é **só sugestão** do Studio (D21); quem manda no duelo é o `duel_setup`.
- Studio nunca calcula dano/cura.

### 13.4.1 Semente — `duel_setup.seed` (D42)

`seed` é dado, e o motor decide o que ele significa:

- **`seed = 0` (ou ausente) = SEM SEMENTE.** Sorteio de verdade a cada partida: quem começa (quando `turn_order` é `random`) e o embaralhamento dos dois baralhos mudam a cada duelo. É o padrão do duelo normal no Studio.
- **`seed != 0` = SEMENTE FIXA.** O mesmo número reproduz o mesmo duelo, carta por carta (mesmo primeiro jogador, mesma mão, mesma ordem do baralho). É o que o Test Lab (doc 10) e o Campo de Testes (D33) usam, porque precisam de repetibilidade.

Antes, `seed = 0` era tratado como uma semente válida e fixa, o que fazia o "aleatório" dar sempre o mesmo resultado — dado travado fingindo ser sorteio. O Studio também mandava `42` fixo em toda partida, o que reforçava o problema.

Quem começa é **sempre dado do motor** (R3). A tela nunca assume que o primeiro é o jogador: ela honra `current_player` e conduz o turno do rival com os sistemas reais quando é a vez dele (D42).

## 13.5 Vitória / derrota V1

- FIXO: `LP<=0 perde; tentar comprar com deck vazio perde (deck out)`.
- DADO futuro: condição especial (ex: juntar X cartas) = efeito dado, motor só executa. V1 só LP + deck out.
- `win.on_lp_zero=true, win.on_deckout=true` fixos V1 (vão no JSON só para compat futura).

## 13.6 FIXO vs DADO (tabela V1)

```text
FIXO (runtime): zonas e tamanhos, ordem fases, compra/descarte, dano/cura, win check, ordem turno.
DADO (JSON): duel_id, duelist_ids, deck_ids, starting_lp, turn_order, seed, arena_id, win flags.
```

## 13.7 Contrato `duel_setup` V1 (JSON trabalho, não distribuição)

```json
{"schema_version":1,"duel_id":"duel_padrao_8000","duelist1":{"duelist_id":"duelist_yugi","deck_id":"deck_yugi_default"},"duelist2":{"duelist_id":"duelist_kaiba","deck_id":"deck_kaiba_default"},"starting_lp":8000,"turn_order":"random","seed":12345,"arena_id":"arena_default","win":{"on_lp_zero":true,"on_deckout":true}}
```

Starter simplificado (tutorial, determinístico):

```json
{"schema_version":1,"duel_id":"duel_starter_4000","duelist1":{"duelist_id":"duelist_hero","deck_id":"deck_starter_hero"},"duelist2":{"duelist_id":"duelist_rival","deck_id":"deck_starter_rival"},"starting_lp":4000,"turn_order":"first_p1","seed":42,"arena_id":"arena_starter","win":{"on_lp_zero":true,"on_deckout":true}}
```

Validações: `schema_version==1; duel_id/duelists/decks/arena existem (quando o projeto tem esses catálogos); starting_lp entre 1 e 99999; seed int; turn_order in [first_p1, first_p2, random]; win booleans presentes`.

Deck: 20-60 cartas no contrato (`deck.schema.json`). Os decks oficiais FM têm 40; o Studio avisa (sem travar) quando o deck não tem 40.

## 13.8 Studio NUNCA calcula

Dano, compra, descarte, quem venceu, resultado fusão, alvo válido, fase atual. Só monta setup e mostra resultado do Astralis (R1/R2).

## 13.9 Implicações

- Preview/Test: `launch Astralis with context {duel_setup, seed}` usa mesmo motor (doc 10).
- Campanha Battle node usa `duel_id` + `on_win/on_lose/retry` (doc 08).
- V2 futuro (não V1): Extra Deck, standby/main2, mão configurável, turn_limit/draw.

## 13.10 Slots D24 (ID fixo + layout separado + escolha livre)

- ID fixo: `p0/p1 + m/s + 0-4` (lado + tipo + índice). Lógica só usa ID/índice.
- Posição XY mora na **arena oficial** (`schemas/examples/arenas/arena_starter.json`, dado puro, só desenho), com limite 0-1920 / 0-1080 no contrato. É a única mesa do jogo (D50, 13.10.3).
- **Sem fallback (D50):** não existe mais "grade padrão embutida". Arquivo faltando ou quebrado = erro honesto: o log avisa e a mesa **não desenha o campo**, em vez de inventar uma mesa.
- Jogador escolhe slot livre (de 5) ao descer da mão, pelo controle. Rival usa o primeiro livre.
- O `arena_id` do `duel_setup` continua no contrato (o dado FM traz `arena_starter`) mas o runtime o **ignora de propósito**: o jogo tem uma mesa só.

## 13.10.1 UMA arena só (D48)

- **A arena oficial é `schemas/examples/arenas/arena_starter.json`** (a "grade larga"): X `632 → 1684` de 263 em 263, Y `p0 monstro 695 / p0 magia 958 / p1 monstro 305 / p1 magia 42`. Mão p0(1240,980,95) e p1(1240,20,60).
- A grade embutida em `core/board_layout.gd` (usada quando o projeto não tem `arenas/`) **não é uma segunda arena**: são os MESMOS números, escritos nas constantes `GRID_X/GAP/Y_*`. O 2D legado repetia essa grade em `duel_legacy2d/duel_board.gd`, mas ele foi removido (D54) - hoje a arena tem UM lugar só.
- **O que era errado (D48):** o JSON já usava a grade larga, mas a grade embutida, a descrição do próprio JSON, o schema e dois testes ainda falavam da grade antiga e estreita (X `780 → 1536`, Y `600/789/317/128`, passo 189). Resultado: quem tinha `arenas/arena_starter.json` via a grade larga, e quem não tinha (projeto novo do Studio) via a grade estreita — **duas telas diferentes**, e a estreita com a mão invadindo a fileira de baixo. Só a larga é a que a câmera da D47 foi calibrada.
- **D50 mudou esta seção (e o D54 fechou):** não existe mais "grade padrão embutida" para cair (13.10.3). A posição vem SO do arquivo da arena oficial; sem ele, o jogo avisa e nao desenha o campo. O que era fallback virou o proprio dado.butidos com os 20 do JSON, trava `SLOT + GAP == 263` e compara o layout lido com os 20 slots do JSON. Se alguém mexer num lado só, a suíte quebra. `test_project_arg.gd` refaz a comparação slot a slot pelo caminho de projeto sem arena.
- Regra para o futuro: **um número de arena vive em dois lugares por necessidade técnica (JSON + fallback), então a igualdade é obrigatória e testada.** Mover a arena = mudar o JSON **e** as constantes, no mesmo commit.

## 13.10.2 A grade PERFEITA (D49) — um valor só, 263

O usuário pediu para "corrigir a distância entre os slots, eles têm que ficar
PERFEITOS", com duas regras explícitas: **(1)** não mexer na distância entre a
fileira de monstros do jogador e a do rival, e **(2)** o valor da distância
horizontal entre slots de monstro é o mesmo em todo o campo.

**A regra que vale agora: UM valor só, `263`, nas SEIS direções do campo.**

| Distância | Antes | Agora |
|---|---|---|
| horizontal, monstro→monstro (2 fileiras) | 263 | **263** |
| horizontal, magia→magia (2 fileiras) | 263 | **263** |
| vertical monstro→magia, jogador | 300 | **263** |
| vertical monstro→magia, rival | 295 | **263** |
| **vertical monstro do jogador ↔ monstro do rival** | 390 | **390 (congelado, regra 1)** |
| horizontal, jogador ↔ rival (mesma coluna) | espelho | espelho |

No dado, então: `p0` monstro 695 / magia 958 (263 abaixo) e `p1` monstro 305 /
magia 42 (263 acima). O 305 e o 695 **não se mexem** — é por isso que só as
fileiras de magia foram movidas.

**O que estava estragando (e por que a tela nunca ficava perfeita).** A
`_pos_slot` da `mesa_3d.gd` tinha, por cima do dado, dois números chutados por
iteração de **calibração de tela** do D44 (`APROXIMA_MAGIA_VOCE = 0.22` e
`APROXIMA_MAGIA_RIVAL = 0.05`) que deslocavam a fileira de magia no Z para
"igualar o vão na tela". Medido em unidades de mundo, o resultado era:

| | horizontal | monstro→magia jogador | monstro→magia rival |
|---|---|---|---|
| antes | 2,1566 | **2,2400** (+4%) | **2,3690** (+10%) |
| agora | 2,1566 | **2,1566** | **2,1566** |

Ou seja: o dado dizia uma coisa e o código deslocava de novo. **O D49 removeu os
dois números.** Não existe mais nenhum desvio por tipo de slot em `_pos_slot`: a
conversão é a mesma para os 4 tipos. Se o vão ficar feio de novo, o dado é que
se muda — nunca um número escondido no código.

**Por que a medida é POR CÓDIGO e não por foto.** O jogo tem a volta da mesa
(D47), então a mesma fileira é vista de lados opostos; e mesmo com a câmera
parada, a perspectiva faz o **mesmo** intervalo de mundo aparecer com **276 px**
na fileira da frente, **257 px** no meio e **220 px** no fundo. Isso é
projeção, não erro do dado — e a lente não pode ser mexida (doc 15 §15.4). Por
isso a trava é em unidades de mundo, e por isso os helpers que mediam o vão em
pixels foram removidos.

**Travas de teste:**
- `test_mesa_3d_oficial.gd::test_d49_grade_perfeita_um_valor_so_e_mao_vem_para_a_camera` — os 20 slots são o dado puro (tolerância 1e-6), o passo horizontal das 4 fileiras é o mesmo número, o vão vertical monstro→magia dos 2 lados é **igual a ele**, a ordem das fileiras continua a do dado, e a distância entre as fileiras de monstros dos 2 lados continua **390** (com um `assert_ne` que impede alguém de "harmonizar" os 390 para 263).
- `test_board_layout.gd::test_espelho_p1_fileiras_perto_longe` — as mesmas três distâncias, medidas no **arquivo** (sem câmera).
- `test_project_arg.gd::test_arena_oficial_e_a_unica_e_a_perfeita` — o arquivo tem 20 slots, um valor só nas seis direções, o 390 congelado, e quem desenha (a mesa 3D) lê o mesmo arquivo.

## 13.10.3 UMA arena, e ela é do jogo (D50)

O usuário, depois de ver que a tela "continuava igual", mandou: *"porra ainda
tem outras arenas nos arquivos? é pra ter só uma, nós só temos uma arena no
jogo, não temos mais; se tiver mais está errado e é pra ser removido"*.

**O que existia: 1 arquivo e 3 cópias dos números.**
1. `schemas/examples/arenas/arena_starter.json` — o arquivo (a mesa de verdade);
2. `core/board_layout.gd` — as constantes `GRID_X`/`GAP`/`Y_*`, o "fallback";
3. ~~`duel_legacy2d/duel_board.gd`~~ - **saiu no D54**: a mesa 2D foi removida (o jogo tem uma tela só, a 3D).

O D48 tinha tornado as três iguais, mas continuavam sendo três. E a (2) era
perigosa: era ela que deixava o jogo cair numa tela diferente **em silêncio**,
quando o arquivo não vinha.

**O que existe agora: UM arquivo, e ZERO números de arena no código.**

| Onde | Antes | Agora |
|---|---|---|
| `core/board_layout.gd` | `SLOT`/`GAP`/`GRID_X`/`Y_*` + `default_pos` com a grade | **nada.** `default_pos` só devolve `NULO` ("não tem posição") |
| `get_pos(layout, slot)` | layout → grade do código → fallback | **layout → fallback do chamador.** Sem layout, `NULO` |
| `project_arena_path(arena_id)` | buscava `projeto/arenas/<id>.json`, senão examples/ | **sempre a arena oficial**; o `arena_id` é lido e avisado como ignorado |
| projeto do Studio | esqueleto com pasta `arenas/` | **sem a pasta** (`PASTAS_ESQUELETO` foi de 9 para 8) |
| pasta `arenas/` num projeto | usada como mesa | **IGNORADA com aviso** ("o jogo tem UMA arena só") |
| `data_loader.gd` (unpack) | copiava a arena para dentro do projeto | **não copia mais** |
| lista de arenas do Studio | `ids_de_projeto("arenas")` | **`["arena_starter"]` fixo** |
| gate da arena no Studio | projeto sem arena = aviso | id diferente da oficial = **erro**; a oficial nunca dá erro |

**Arquivo faltando ou quebrado = erro honesto.** Não existe mais para onde cair:
`valida_arena_oficial` lista o que falta, o log avisa, e a mesa 3D **não desenha
o campo** em vez de inventar uma mesa. (O jogo usa `push_warning` + `print` e
não `push_error`, porque o GUT conta `push_error` como erro inesperado — o
comportamento é o mesmo: nada é desenhado.)

**O que foi perdido, e é escolha do usuário:** um projeto não pode mais ter mesa
própria. Mover slots por projeto era uma capacidade V2 do D24 ("editor futuro
move XY") que nunca teve editor. Se um dia ele quiser isso de volta, é um
arquivo por projeto + um seletor — e aí são duas mesas **por escolha**, não por
acidente.

**Travas de teste:**
- `test_board_layout.gd::test_d50_sem_grade_no_codigo` — `default_pos` e `default_layout` são `NULO`, `project_arena_path` cai na oficial para qualquer id, e o projeto do Studio não tem `arenas/`.
- `test_board_layout.gd::test_sem_layout_nao_inventa_posicao` e `test_arquivo_ruim_nao_inventa_posicao` — sem layout ou com arquivo ruim não sai posição nenhuma, e o 2D não desenha.
- `test_project_arg.gd::test_pasta_arenas_no_projeto_e_ignorada_com_aviso` — o jogo de verdade, como processo filho, avisa que ignorou e usa a oficial.
- `test_project_arg.gd::test_arena_oficial_e_a_unica_e_a_perfeita` — a grade perfeita (D49) medida no arquivo, e o 2D legado no mesmo arquivo.

## 13.11 Mão D25 (posição editável + rival de costas)

- Posição mora na arena: `hand.p0{x,y,step}` (você, aberta) + `hand.p1{x,y,step}` (rival, de costas). Mover esq/dir = mudar `x` no JSON, sem quebrar regra.
- Padrão: p0(1240,980,95) centrada sob o campo, p1(1240,20,60) mini no topo. Sem `hand`, usa esse padrão.
- Rival nunca mostra frente: só contagem, de costas, sem clique, sem vazar id/nome.
- Animação curta presa à carta, sem voo atravessando a tela.

## 13.12 Onde os dados vêm (D29)

- O jogo lê **a pasta do projeto** via `--project <pasta>`, não `schemas/examples/`. `schemas/examples/` é dado de TESTE e nunca é a fonte em produção.
- Consequência (D50): um projeto sem `duel_setup.json` sobe com LP 4000 e baralhos vazios, e a MESA não vem do projeto — vem da arena oficial do jogo (13.10.3), que é a única. O duelo rápido do Studio monta o `duel_setup` na hora e passa por `--setup`.
- O `examples/` ainda é a base embutida quando o jogo roda **sem** `--project` (é assim que os testes rodam).

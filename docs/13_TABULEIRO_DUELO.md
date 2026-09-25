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
- Posição XY mora em `arenas/arena_*.json` (dado puro, só desenho), com limite 0-1920 / 0-1080 no contrato. Editor futuro move XY sem renomear/apagar.
- Fallback: sem arena, ou arena inválida, usa a **grade padrão embutida** (1920x1080). Nunca quebra o jogo.
- Jogador escolhe slot livre (de 5) ao descer da mão, pelo controle. Rival usa o primeiro livre.
- O fallback embutido tem exatamente os mesmos números do `arena_starter.json` — logo um projeto sem arena vê a mesma tela.

## 13.11 Mão D25 (posição editável + rival de costas)

- Posição mora na arena: `hand.p0{x,y,step}` (você, aberta) + `hand.p1{x,y,step}` (rival, de costas). Mover esq/dir = mudar `x` no JSON, sem quebrar regra.
- Padrão: p0(1240,980,95) centrada sob o campo, p1(1240,20,60) mini no topo. Sem `hand`, usa esse padrão.
- Rival nunca mostra frente: só contagem, de costas, sem clique, sem vazar id/nome.
- Animação curta presa à carta, sem voo atravessando a tela.

## 13.12 Onde os dados vêm (D29)

- O jogo lê **a pasta do projeto** via `--project <pasta>`, não `schemas/examples/`. `schemas/examples/` é dado de TESTE e nunca é a fonte em produção.
- Consequência: um projeto sem `arenas/` usa a grade padrão do runtime (13.10), e um projeto sem `duel_setup.json` sobe com LP 4000 e baralhos vazios. O duelo rápido do Studio monta o `duel_setup` na hora e passa por `--setup`.
- O `examples/` ainda é a base embutida quando o jogo roda **sem** `--project` (é assim que os testes rodam).

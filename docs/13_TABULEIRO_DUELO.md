# 13 — TABULEIRO E DUELO V1

ORIGEM: desdobramento de `05_RUNTIME_DUELO.md` + contrato `04_CONTRATO_DADOS.md`
STATUS: AUTHORITATIVE V1 (decisão Lead 2026-09-23, insumos runtime+systems)
OWNER: lead (lógica runtime-owned, contrato systems-owned)

## 13.1 Zonas fixas V1

Runtime fixa nomes, tamanhos e o que cada zona aceita. Dado só define conteúdo.

```text
deck: pilha, máx 60 cartas, só Card IDs. Compra do topo.
hand: mão do jogador. Ver 13.3.
monster_zone[3]: até 3 monstros em campo.
spell_zone[3]: até 3 magias/armadilhas em campo.
graveyard: pilha de destruídos/usados.
banished: pilha simples de removidos.
```

Sem zona fusão V1: fusão consome mão+campo e entrega no campo.
Sem Extra Deck V1 (adiado por R5).

## 13.2 Fases do turno V1 (fixas, nesta ordem)

```text
DRAW → MAIN → BATTLE → END
```

- DRAW: compra 1 (ver 13.3).
- MAIN: 1 invocação normal, magias, posicionar, fusão.
- BATTLE: 1 ataque por monstro.
- END: checa vitória/derrota, descarta se estourar mão.

`standby / main2` adiados. Ordem e permissões são LOGIC fixa.

## 13.3 Mão V1 (regra universal, fixa)

- Inicial: 5 cartas.
- Compra: 1 por turno, inclusive turno 1 (sem passe V1).
- Limite: 7 no END, descarte obrigatório do excesso.
- `hand_size / max_hand` NÃO vão no JSON V1 (fixos, reduz matriz de teste).

## 13.4 LP V1

- FIXO: existe LP, fórmula dano/cura, LP nunca passa do inicial, checagem após dano + no END.
- DADO: `starting_lp` por duelo (padrão 8000, starter 4000).
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

Validações: `schema_version==1; duel_id/duelist_id/deck_id/arena_id existem; starting_lp>0; seed int; turn_order in [first_p1, first_p2, random]; win booleans presentes; deck 40-60 cartas (regra deck, não tabuleiro)`.

## 13.8 Studio NUNCA calcula

Dano, compra, descarte, quem venceu, resultado fusão, alvo válido, fase atual. Só monta setup e mostra resultado do Astralis (R1/R2).

## 13.9 Implicações

- Preview/Test: `launch Astralis with context {duel_setup, seed}` usa mesmo motor (doc 10).
- Campanha Battle node usa `duel_id` + `on_win/on_lose/retry` (doc 08).
- V2 futuro (não V1): Extra Deck, standby/main2, mão configurável, turn_limit/draw.

## 13.10 Slots D24 (ID fixo + layout separado + escolha livre)

- ID fixo: `p0/p1 + m/s + 0-4` (lado + tipo + índice). Lógica só usa ID/índice.
- Posição XY mora em `arenas/arena_*.json` (dado puro, só desenho). Editor futuro move XY sem renomear/apagar.
- Fallback: sem arena ou arena ruim, usa grade padrão 1920x1080. Nunca quebra o jogo.
- Jogador escolhe slot livre ao descer da mão (clica carta, depois slot vazio). Rival usa primeiro livre.

## 13.11 Mão D25 (posição editável + rival de costas)

- Posição mora na arena: `hand.p0{x,y,step}` (você, aberta) + `hand.p1{x,y,step}` (rival, de costas). Mover esq/dir = mudar `x` no JSON, sem quebrar regra.
- Padrão starter: p0(1240,980,95) centrada sob o campo, p1(1240,20,60) mini no topo. Sem `hand`, usa esse padrão.
- Rival nunca mostra frente: só contagem, de costas, sem clique, sem vazar id/nome.
- Animação curta presa à carta, sem voo atravessando a tela.

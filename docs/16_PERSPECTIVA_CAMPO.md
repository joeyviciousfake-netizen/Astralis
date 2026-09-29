# 16 — PERSPECTIVA DO CAMPO (plano da próxima leva)

VERSION: 1.0
STATUS: **PLANO — NADA IMPLEMENTADO.** O usuário desenhou o plano com o Lead em
2026-09-28; a execução começa na etapa 1, com o aval do usuário.
OWNER: lead (a implementação é do runtime: `duel3d/mesa_3d.gd`)
ORIGEM: conversa de 2026-09-28, depois de ver a faixa 2D (D45/D45b, já no git)
DEPENDES: `13_TABULEIRO_DUELO.md`, `14_EXPERIENCIA_USUARIO.md`,
`15_VISUAL_DUELO.md`, D17, D18, D40, D41, D42, D45, D45b

> **Regra de ouro desta etapa: NÃO GIRA NADA.** Nem o campo, nem a câmera, nem o
> céu, nem os ladrilhos. O que muda é **para onde cada carta é desenhada**.
> Se uma ideia de implementação "girar" a mesa, ela está errada por definição.

---

## 16.1 O pedido do usuário (palavras dele, sem interpretação)

> "no jogo yugioh forbidden memories quando passamos a vez para o adversário o
> campo do jogo gira e então vemos o campo pelo visão do adversário na vez dele,
> as cartas da mão dele aparecem na tela como se fossem minhas mas claro que o
> conteúdo delas não aparecem pois o jogo coloca uma imagem padrão nas cartas
> onde era pra estar as informações das cartas. então ele faz a jogada dele e
> quando termina o campo gira novamente e volta para a minha visão do campo."

> "o que eu quero é mais ou menos igual isso, **não vai ter campo girando**, mas
> o que eu penso é de ver o campo pela visão do inimigo igual no forbidden
> memories. [...] as minhas cartas da mão vão fazer um efeito de ir para baixo
> para sumir da tela e vai subir as cartas da mão dele, apesar das cartas da mão
> dele estarem viradas para mim pois vou estar vendo da visão dele, vamos
> deixar elas com uma imagem padrão também [...] como vamos estar vendo o campo
> da visão dele, vamos ter que jogar os monstros do meu lado do campo no campo do
> outro lado e os monstros do campo dele vão vir para o meu. essa troca de
> monstros eu penso que pode acontecer de um modo suave, como um efeito da
> **carta sumindo do meu campo e aparecendo no campo dele** e a dele vindo para
> o meu."

E o motivo (o ganho real):

> "essa minha ideia vai ajudar também a não precisar ficar sempre espelhando a
> mão e o campo do inimigo, pois tecnicamente vai ser usado sempre só um lado do
> campo"

---

## 16.2 As decisões do usuário (travadas — não reabra sem pedir)

| # | Decisão | Exato |
|---|---|---|
| D1 | **A perspectiva da tela é a de quem está jogando.** Na vez dele, a tela mostra o campo como ele veria. | `current_player` decide |
| D2 | **Nada gira.** O campo, a câmera e o céu ficam parados. | nunca `frustum_offset`, nunca deslocamento de X, nunca giro de câmera (D41/D42 intactos) |
| D3 | **No campo, ninguém viaja.** A carta **esmaece** (some) onde está e **aparece esmaecendo** do outro lado. Sem voar, sem atravessar a tela, sem deslizar. | "a carta sumindo do meu campo e aparecendo no campo dele" |
| D4 | **Todas as cartas de uma vez**, num só baque. Não é fila uma a uma. | decisão do usuário |
| D5 | **A coluna é ESPELHADA**: a carta da coluna 0 vai para a coluna 4, e assim por diante. O arranjo final é como uma mesa virada, feito carta por carta. | o usuário escolheu "coluna espelhada" |
| D6 | **A carta que fica na fileira de cima é desenhada de cabeça para baixo** (o dono lê ela de cabeça baixa, como no FM). | o usuário escolheu "igual o FM" |
| D7 | **Mão sempre nos dois lugares.** A de quem joga fica embaixo (a sua **aberta**, a dele **virada**) e a do passive fica em cima, **sempre virada**: na sua vez é a dele no topo virada; na vez dele é a sua no topo virada. | decisão do usuário |
| D8 | **A faixa do meio e as placas de nome NÃO espelham.** Continuam sendo o painel do jogador. | decisão do usuário |
| D9 | Efeito da mão: a sua **desce e sai da tela**, a dele **sobe** para o lugar de baixo. | ou seja: a mão é a única coisa que se desloca |

O bloco do TURNO da faixa (D45, item 7) já muda de cor com `current_player`:
com a perspectiva, **a cor da faixa e a tela passam a concordar** — dá para ler
de quem é a vez só de olhar a tela.

---

## 16.3 O que existe hoje (e por que isso dói)

A tela tem **duas geometrias** ao mesmo tempo:

- **D18 (espelho do rival):** o lado do rival é desenhado espelhado no X, para
  fingir que é "a mesma mesa vista do outro ângulo". O dado (`arenas/*.json`)
  tem posição dos dois lados, e `_pos_slot(lado, tipo, índice)` já devolve o
  espelhado.
- **D45 item 8 (espelho da mão do rival):** a mão dele é desenhada invertida
  para a carta comprada entrar pela esquerda dele (a 5ª posição na mão DELE).
- Cada animação do arquivo (`_redesenhar`, `_atacar3d`, a compra, a fila de
  fusão, a carta ao centro, o cursor) **repetiu a suposição "p0 = baixo"** em
  vez de repetir a mesma decisão dentro de cada uma.

E "altura do chão" na tela não é uma linha: o ladrilho é um plano visto de
lado (a fileira de monstros ocupa uma faixa de pixels). Foi por isso que a
faixa 3D do D44 virou 2D (D45): em 2D a posição é o pixel.

---

## 16.4 O ganho (por que vale a pena)

1. **Some o espelho.** Se o lado de baixo é sempre de quem joga, "a fileira de
   cima" é só a **rotação** da de baixo. Uma regra, um número, um caminho de
   desenho. A mão também (só o de quem joga tem leitura; o de cima é sempre
   verso).
2. **Some o caso especial do D45 item 8** (a 5ª posição espelhada do rival):
   com a mão do passive sempre virada, a ordem delas não vaza informação e a
   regra da 5ª posição vale igual para os dois.
3. **O dado não muda.** `schemas/examples/arenas/*.json` continua como está
   (D17/D18). A rotação sai de graça de `_pos_slot(lado_visual, tipo,
   coluna_visual)`, que já sabe o espelho do dado.
4. **A câmera não é tocada** — a invariante do doc 15 §15.4 continua valendo.
5. **É R1 inteiro:** `duel/`, `core/`, `ui/` e `schemas/` não mudam. A
   perspectiva é uma **função do `current_player` do motor**, não um estado
   novo que possa dessincronizar.

---

## 16.5 A arquitetura (uma decisão, um lugar)

**Uma função, usada por TODO desenho e TODA animação:**

```gdscript
# ONDE a carta do lado `lado`, coluna `i` é DESENHADA agora.
# Perspectiva do jogador 0: cada coisa onde está.
# Perspectiva do jogador 1: cada coisa no lado OPOSTO e na coluna OPOSTA.
# (o "lado oposto + coluna oposta" é o arranjo virado, feito por dados)
func _vis(lado: int, i: int) -> Vector2i:   # x = lado visual, y = coluna visual
    if int(_st.current_player) == 0:
        return Vector2i(lado, i)
    return Vector2i(1 - lado, 4 - i)
```

Regras que decorrem (e que o teste tem que cravar):

- **A fileira de baixo é sempre de quem joga.** Na sua vez, são as suas cartas
  embaixo; na dele, são as dele embaixo.
- **A coluna espelha junto** (0↔4, 1↔3, 2 fica).
- **A carta de cima é de cabeça para baixo** (o dono lê de cabeça baixa).
- **O estado não se move:** `players[lado]["monster"][i]` é a MESMA carta antes
  e depois da troca. A troca é só de desenho.

**A troca (uma rotina só, para as duas direções):**

1. Chama `_redesenhar` com o novo `current_player`.
2. Cada carta do campo: **esmaece** na posição antiga e **aparece esmaecendo**
   na nova (alpha). Todas no mesmo quadro (D4).
3. A mão de baixo e a de cima: **deslizam** (a de baixo sai para fora da
   borda, a de cima entra) e trocam de dono, sempre virada a de cima.
4. A faixa e as placas de nome **não se mexem** (D8).
5. Duração sugerida: ~0,5 s, curva suave. **Falta decidir** (16.7) se o
   START/confirmar pula a animação.

**Todos os lugares que precisam perguntar "de que lado eu desenho?"** (a lista
completa é a busca por `_pos_slot(`, `_pos_mao_arco(`, `_rot_deitada(`,
`_deitar_carta(`, e os tweens de carta):

| Onde | O que muda |
|---|---|
| `_redesenhar` | posições do campo e das duas mãos; qual mão é a de baixo; cara (aberta/virada) |
| `_pos_mao_arco` | a mão de baixo é a de quem joga; a de cima é a do outro, sempre virada, e **espelhada** (é a parte de cima: vista do outro lado) |
| `_deitar_carta` / `_rot_deitada` | o `lado` que decide a rotação 180° passa a ser o **lado visual** |
| `_atacar3d` | o ataque sai da fileira de baixo (de quem joga) e vai para a de cima |
| compra da carta | a carta nova entra no fim do baralho e aparece na mão de baixo (só quando é a vez do jogador 0) |
| fila de fusão | a mão é sempre a de baixo; as cartas fundidas descem para a fileira de baixo |
| carta ao centro / menus | seguem a carta focada (nada a fazer se usarem a posição visual) |
| `_posicionar_cursor` | o cursor é do **jogador 0**; na vez dele, escondido (decidir 16.7) |

---

## 16.6 As etapas (com PROVA em cada uma)

1. **A camada de perspectiva, sem mudar a tela.** A função `_vis` + todo
   desenho passando por ela, com a perspectiva **travada no jogador 0**.
   *Prova:* a foto fica **idêntica** à de hoje + teste que trava o visual atual.
2. **A troca do campo.** A perspectiva passa a seguir `current_player`; as
   cartas esmaecem e trocam de lado; a coluna espelha; a de cima vira 180°.
   *Prova:* duas fotos (uma na sua vez, uma na dele) + teste da fileira de
   baixo = de quem joga, da coluna espelhada, e de que **o estado não se move**.
3. **As mãos.** Um caminho só: a de baixo é a de quem joga (aberta só se for a
   sua), a de cima é a do outro, **sempre virada e espelhada**.
   *Prova:* fotos + teste da cara e da ordem.
4. **As animações que seguem as cartas**: ataque, compra, fusão, carta ao
   centro; esconder o cursor na vez dele.
   *Prova:* jogo rodando (jogo de verdade, com o rival jogando) + GUT.
5. **Acabamento.** Tempo/curva, ferramenta de calibração (`--mesa3d-calib=1`),
   fotos para o registro, docs.

Cada etapa é um commit, com o GUT verde. O usuário confere a foto antes de
aprovar a próxima.

---

## 16.7 O que ainda falta o usuário decidir

1. **Na vez do rival, o painel esquerdo** (a carta focada) congela na última
   carta que você focou? (Lead sugere sim: você não pode focar nada quando não
   é sua vez.)
2. **No Campo de Testes** (aba de testes do Studio, D33/D34) a perspectiva
   também troca quando o dummy joga? (Lead sugere que troque, para ser UMA
   regra só; se ficar desorientado, a gente abre uma exceção depois.)
3. **Pular a animação** com o START? (Lead sugere sim: você não fica preso.)
4. **Duração e curva** da troca (Lead sugere 0,5 s, `TRANS_CUBIC`/`EASE_IN_OUT`).

Nada disso trava a etapa 1.

---

## 16.8 Os testes que a trava tem que ter (GUT)

- `p0` joga: monstro do p0 na fileira de baixo, coluna natural; o do p1 na de
  cima, coluna espelhada.
- `p1` joga: o oposto (o do p0 na de cima, coluna espelhada, virado 180°; o
  do p1 na de baixo, coluna natural).
- **O estado não se move**: a mesma carta em `players[0]["monster"][0]` antes e
  depois (R1 na prática).
- **A mão**: a de baixo é a de quem joga; **aberta só quando é a do jogador
  0**; a de cima **sempre virada**.
- A faixa e as placas de nome **não mudam de lugar** com a perspectiva.
- A câmera **não muda** (posição, FOV, `frustum_offset` = 0) — as travas do
  D41/D42 continuam valendo.
- **Volta**: depois que a vez volta, tudo volta ao lugar de antes (a troca é
  reversível).
- O `diff` do commit não toca `duel/`, `core/`, `ui/`, `schemas/`.

---

## 16.9 Os custos (honestos)

- Na vez dele, **os seus monstros ficam de cabeça para baixo** na fileira de
  cima: você não lê o ATK dos seus enquanto ele joga. Em troca você lê o ATK
  **dos dele** (que fica de frente, embaixo), que é o que importa para se
  defender. O usuário aceitou isso explicitamente.
- A troca de perspectiva acontece duas vezes por rodada de turnos (uma para
  entrar na vez dele, uma para voltar). Se demorar, cansa.
- É a maior mudança de desenho da mesa depois do D41: toca 7-8 funções do
  `mesa_3d.gd` (ver 16.5). Nada de `duel/`/`core/`/`ui/`.

---

## 16.10 O que NÃO fazer (erros que a conversa já pagou)

- **Não girar o campo, a câmera ou a janela.** A câmera nunca é deslocada
  (doc 15 §15.4).
- **Não fazer a carta do campo voar/atravessar a tela.** O campo só esmaece
  (D3). Só a mão desliza (D9).
- **Não fazer uma por uma.** Todas de uma vez (D4).
- **Não mexer no dado** (`arenas`, `duel_setup`) para isso: a rotação sai da
  leitura do lado/coluna opostos.
- **Não guardar a perspectiva em variável de estado.** Ela é `current_player`,
  sempre. Se ficar dessincronizada, o desenho mente (R1).
- **Não espalhar o "de que lado" em cada animação.** Uma função só; se cada
  animação decidir por si, volta a mesma bagunça que o espelho do D18 criou.

---

## 16.11 ONDE ESTÁ A EXECUÇÃO (para a próxima conversa)

**Status: NADA IMPLEMENTADO.** O último commit é o da D45b (faixa 2D com as
cores, o bloco limpo, o número branco, a foto do cemitério e a cor do turno).
A partir dele:

1. Abrir `docs/16_PERSPECTIVA_CAMPO.md` (este arquivo) **antes** de mexer em
   qualquer coisa.
2. Conferir o `docs/SESSAO_ATUAL.md` (o caderno) e o `docs/DECISOES.md`.
3. **Perguntar ao usuário se pode começar a etapa 1** (a camada de
   perspectiva, com a tela igual à de hoje) — ele ainda não deu o "pode
   começar" para essa leva.
4. Fazer a etapa 1, provando com foto idêntica + GUT verde, e parar para o
   usuário olhar.


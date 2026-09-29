# 16 — PERSPECTIVA DO CAMPO (plano da próxima leva)

VERSION: 1.2
STATUS: **ETAPAS 1 E 2 IMPLEMENTADAS, O RESTO NÃO.** O usuário desenhou o
plano com o Lead em 2026-09-28; a etapa 1 (a camada de perspectiva, com a tela
igual à de hoje) e a etapa 2 (a troca do campo) foram feitas em 2026-09-29 —
ver §16.12. As perguntas §16.7 1 e 3 foram respondidas pelo usuário (D46b). A
execução continua pela etapa 3 (as mãos), com o aval do usuário.
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
| D5 | **A COLUNA DE TELHA INVERTE**: a carta que está no slot 1 (esquerda→direita) aparece no slot 5 quando a vez passa, e a do slot 5 no slot 1 — **vale para as cartas dos DOIS lados**. | o usuário, depois de ver a foto da etapa 2 (2026-09-29). Atenção: a inversão NÃO vem de espelhar a coluna em `_vis` — vem do espelho de X que o lado 1 da arena já tem no dado (D18). Espelhar a coluna também fazia os dois se anular. |
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
# Perspectiva do jogador 1: cada coisa no lado OPOSTO, na MESMA coluna.
# (a inversão de TELHA — slot 1 vira slot 5 — vem sozinha do espelho de X do
#  lado 1 no dado; se a coluna fosse espelhada aqui, os dois se anulariam)
func _vis(lado: int, i: int) -> Vector2i:
    if int(_st.current_player) == 0:
        return Vector2i(lado, i)
    return Vector2i(1 - lado, i)
```

Regras que decorrem (e que o teste tem que cravar):

- **A fileira de baixo é sempre de quem joga.** Na sua vez, são as suas cartas
  embaixo; na dele, são as dele embaixo.
- **A coluna de TELHA inverte** (D5, corrigido pelo usuário): o slot 1 vai para
  o 5, e o 5 para o 1, nos dois lados. É o espelho de X do lado 1 no dado
  fazendo o serviço — a coluna do dado NÃO é espelhada.
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

| # | Etapa | PROVA | Status |
|---|---|---|---|
| 1 | **A camada de perspectiva, sem mudar a tela.** A função `_vis` + todo desenho passando por ela, com a perspectiva **travada no jogador 0**. | a foto fica **idêntica** à de hoje + teste que trava o visual atual | **FEITA 2026-09-29** — ver §16.12 |
| 2 | **A troca do campo.** A perspectiva passa a seguir `current_player`; as cartas esmaecem e trocam de lado; a coluna espelha; a de cima vira 180°. | duas fotos (uma na sua vez, uma na dele) + teste da fileira de baixo = de quem joga, da coluna espelhada, e de que **o estado não se move** | **FEITA 2026-09-29** — ver §16.12 |
| 3 | **As mãos.** Um caminho só: a de baixo é a de quem joga (aberta só se for a sua), a de cima é a do outro, **sempre virada e espelhada**. | fotos + teste da cara e da ordem | **FEITA 2026-09-29** — ver §16.14 |
| 4 | **As animações que seguem as cartas**: ataque, compra, fusão, carta ao centro; esconder o cursor na vez dele. | jogo rodando (jogo de verdade, com o rival jogando) + GUT | a fazer |
| 5 | **Acabamento.** Tempo/curva, ferramenta de calibração (`--mesa3d-calib=1`), fotos para o registro, docs. | 2 fotos (mão + campo) | a fazer |

Cada etapa é um commit, com o GUT verde. O usuário confere a foto antes de
aprovar a próxima.

---

## 16.7 O que ainda falta o usuário decidir

**FECHADAS em 2026-09-29 (D46b), quando a etapa 1 começou:**

1. **Na vez do rival, o painel esquerdo** — **DECIDIDO: ele continua vivo.**
   Ele mostra a carta que o RIVAL está vendo, mas com uma **imagem
   padronizada**: não revela qual é a carta de verdade nem os dados dela
   (sem nome/ATK/DEF/tipo/descrição). O painel não congela — ele troca de
   conteúdo por um conteúdo neutro. (Implementa na etapa 2.)
3. **Pular a animação** com o START? — **DECIDIDO: NÃO. Não existe pular.**
   A troca de perspectiva roda sempre, inteira, quando a vez passa. O START é
   o que encadeia a animação, não um botão de pular.

**AINDA EM ABERTO (o usuário não respondeu; o Lead vai do padrão abaixo e o
usuário muda quando quiser, D23):**

2. **No Campo de Testes** (D33/D34) a perspectiva também troca quando o
   dummy joga? *Padrão do Lead: troca*, para ser UMA regra só; se ficar
   desorientado, abre-se uma exceção depois.
4. **Duração e curva** da troca. *Padrão do Lead: 0,5 s, `TRANS_CUBIC` /
   `EASE_IN_OUT`* (a sugestão original deste doc).

Nada disso trava a etapa 1.

---

## 16.8 Os testes que a trava tem que ter (GUT)

- `p0` joga: monstro do p0 na fileira de baixo, coluna natural; o do p1 na de
  cima.
- `p1` joga: o oposto (o do p0 na de cima, virado 180°; o do p1 na de baixo).
- **A inversão é medida em COLUNAS DE TELA** (o X projetado pela câmera de
  verdade, ordenado da esquerda para a direita): a carta que estava no slot 1
  vai para o 5 e a do 5 para o 1, **nos dois lados** (D5). Medir pelo índice
  do dado não prova nada, porque na fileira do rival o dado já vem espelhado.
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

## 16.11 ONDE ESTÁ A EXECUÇÃO

**Status: ETAPAS 1, 2 E 3 FEITAS (2026-09-29).** A próxima é a **etapa 4** (as
animações que seguem as cartas: ataque, compra, fusão, carta ao centro, e
esconder o cursor na vez do rival), e ela espera o usuário jogar.

1. Abrir `docs/16_PERSPECTIVA_CAMPO.md` (este arquivo) **antes** de mexer em
   qualquer coisa.
2. Conferir o `docs/SESSAO_ATUAL.md` (o caderno) e o `docs/DECISOES.md`.
3. Conferir o §16.12, §16.13 e §16.14 (o que as três etapas deixaram pronto).
4. **Etapa 4**: as animações. Ela exige o jogo rodando de verdade, com o rival
   jogando — o resto das etapas foi provado por foto e GUT, esta precisa do
   jogador na frente do teclado/controle.

## 16.12 O que a etapa 1 deixou pronto (2026-09-29)

**Uma função, e ela é a decisão:**

```gdscript
func _perspectiva() -> int:
    return 0        # ETAPA 1 TRAVADA. A etapa 2 troca por int(_st.current_player).

func _vis(lado: int, i: int) -> Vector2i:   # (lado, coluna) do DADO -> da TELA
    if _perspectiva() == 0:
        return Vector2i(lado, col)
    return Vector2i(1 - lado, COLUNAS_CAMPO - 1 - col)
```

Mais dois atalhos que usam `_vis` por dentro, para ninguém chamar `_pos_slot`
com lado do dado por engano: `_pos_slot_do_dado(lado, tipo, i)` (posição) e
`_x_do_slot(lado, tipo, i)` (só o X, para quem anda pela posição visível).

**O que JÁ passa por `_vis`:**

| Onde | O que faz |
|---|---|
| `_redesenhar` (campo) | posição e giro de 180° de cada carta do campo |
| `_posicionar_cursor` (as 4 fileiras) | onde a moldura de foco cai |
| `_vizinho3d` + a troca de fileira | o vizinho pela posição visível (`_x_do_slot`) |
| o print de boot do slot p0_m2 | diagnóstico |

**O que a etapa 1 NÃO tocou (de propósito, é das etapas seguintes):**
as duas mãos (`_pos_mao_arco`/`_y_da_mao`/`_passo_mao`), a compra, a fila de
fusão, a carta ao centro, o ataque, o cursor escondido, a animação da troca.
E também, com motivo escrito no código: `_painel_slot` (as 20 peças de vidro
são construídas uma vez com as DUAS fileiras, e a perspectiva só troca os
lugares entre elas — o conjunto é o mesmo antes e depois) e
`_borda_da_fileira_px`/`_extensao_da_fileira_px` (medem a faixa do meio, que é
sempre o painel do jogador, D8).

**A prova de que a tela não mudou (duas, independentes):**
- **Foto, pixel a pixel.** Mesmo comando, mesmo projeto de teste (o das 722
  artes, pasta de temp), antes e depois: **113 pixels** diferentes em
  2.001.046 (0,006%). E o **controle** — o código ORIGINAL rodando duas vezes
  — difere em **1129 pixels**, na mesma região, porque o cursor de foco
  **pulsa** (`_process`, `1.0 + 0.04*sin(pulso)`, depende do tempo do frame).
  Então a mudança da etapa 1 é **10x menor que o ruído do próprio jogo**.
  As fotos: `e1_ANTES.png`, `e1_FINAL.png` e o lado a lado
  `e1_COMPARA_antes_depois.png` (pasta de temp, fora do repo por R8).
- **GUT.** Arquivo novo `astralis/testing/test_perspectiva_campo.gd` (5
  testes / 57 asserts) que trava: `_vis` identidade nos 20 lugares (e
  **também** com `current_player = 1`, que é o que a etapa 2 vai mudar de
  propósito), a carta desenhada exatamente onde `_vis` mandou, o giro pelo
  lado VISUAL, o estado não se mexer no redesenho, a navegação visível certa
  nos dois lados, e a faixa do meio não espelhar (D8). **Sabotado** de
  propósito (`_perspectiva()` devolvendo 1) e o teste pegou.
  Suíte inteira: **172/172, 3738 asserts, 0 SCRIPT ERROR, 0 orphans**.

**Erro meu desta etapa (no caderno, não esconder):** a primeira versão do
teste affirmava que no lado 1 a coluna 4 fica à direita da coluna 0. É o
**contrário** — o lado 1 é espelhado no dado (D18), então lá a coluna 0 é a
da direita. O teste estava errado, não o código; a trava real é "andar para a
direita aumenta o X de tela", testada no meio da fileira. Primeira versão
tambémAssume que o p1 consegue invocar na fase em que o GUT roda (não
consegue — a mão dele não tem monstro nessa seed), então o teste passou a
montar a instância pelo **construtor real** (`SummonSystem.construir_instancia`,
o único do jogo, R1), que é o que o teste precisa: uma instância de verdade no
estado, não uma regra de invocação.


---

## 16.13 A ETAPA 2 — a troca do campo (2026-09-29)

**O que mudou:** `_perspectiva()` passou a devolver o `current_player` do
MOTOR (lido na hora, nunca guardado). Só isso muda a tela; todo o resto do
desenho já estava pronto desde a etapa 1.

**A troca, uma rotina para as DUAS direções** (`_trocar_perspectiva`):

1. as cartas do campo que estão na tela viram **fantasmas** e ficam **no mesmo
   lugar** — elas esmaecem onde estão (D3: nada viaja, nada atravessa a tela);
2. a tela nova é desenhada por baixo, no lugar novo, e as cartas **aparecem
   esmaecendo**;
3. tudo no mesmo baque (D4), 0,5 s, `TRANS_CUBIC`/`EASE_IN_OUT` (o padrão do
   §16.7; o usuário pode mexer em `TROCA_DURACAO`). **O START não pula**
   (D46b).

**Onde ela acontece:** dentro do próprio `_redesenhar`. Ele é o funil por onde
o motor entrega a vez (START, `_rival_auto`, `_levar_vez_para_o_jogador`), então
não existe outro lugar que precise saber da troca — e `_perspectiva_antiga`
só serve para saber que a vez mudou e rodar a troca **uma** vez.

**A carta de cima é lida de cabeça para baixo (D6):** o giro de 180° já saía do
LADO VISUAL desde a etapa 1, então ele acompanha a troca sozinho.

**D46b, o painel esquerdo na vez do rival:** ele **continua vivo** (dá para
focar o que quiser), mas mostra a **imagem padronizada** (o verso, que já é
asset do jogo) e **nenhum dado** — sem nome, ATK/DEF, tipo, descrição,
estrelas, orbe nem contador.

**As duas ferramentas de prova que esta etapa exigiu** (doc 15 §15.0 já tinha
o `--mesa3d-calib` como ferramenta do mesmo tipo; zero regra, sem a flag o jogo
é exatamente o de sempre):

- `--mesa3d-foto-frame=N` — em qual QUADRO a foto sai (padrão **90**, o de
  sempre).
- `--mesa3d-auto-passa=s` — passa a vez sozinho `s` segundos depois de a tela
  ficar pronta, pelo **mesmo caminho do START**.

**Por que elas foram necessárias:** a perspectiva só aparece quando a VEZ
PASSA, e a vez do jogador espera o START — que ninguém aperta numa prova
automática. E `duel_manager.gd:80` **força `first_p1` quando o setup tem
`test_state`** (regra do Campo de Testes, D33), então não existe caminho
automático até a vez do rival *com o campo cheio* por outro meio.

**A prova:**

- **Duas fotos** (mesmo projeto de teste das 722 artes): `e2_sua_vez.png` e
  `e2_rival.png`, mais o lado a lado `e2_COMPARA_sua_vez_vs_rival.png` e o zoom
  `e2_zoom_fileira_de_cima.png` (pasta de temp, fora do repo por R8). A foto da
  vez do rival saiu com `perspectiva 1` no log, e nela: as 4 cartas do jogador
  subiram de cabeça para baixo com a coluna espelhada, as do rival desceram,
  e o painel esquerdo mostra só o verso.
- **A visão do JOGADOR não mudou:** etapa 1 × etapa 2 na sua vez = **138 px** em
  2.001.046 (0,007%) — o mesmo ruído do cursor pulsante. Entre as duas fotos da
  etapa 2 são 681.780 px: a tela **virou mesmo**.
- **GUT:** `test_perspectiva_campo.gd` foi de 5 para **8 testes / 116
  asserts**, e a suíte inteira ficou **175/175, 3801 asserts, 0 SCRIPT ERROR,
  0 orphans**. O teste novo da troca é sabotado e pego.
- **Um teste antigo precisou mudar** (`test_mesa_3d_oficial.gd`, "carta no
  painel"): ele afirmava que a carta do dado `p0_m0` fica no painel `p0_m0`, o
  que é justamente o que a etapa 2 troca. Agora ele confere o painel do
  ladrilho **visual** e, junto, que a carta continua sendo a do **dado**
  (`slot_id` é a identidade dela). O painel em si não mudou: as 20 peças são
  construídas uma vez com as duas fileiras e a perspectiva só troca os lugares
  entre elas.

**Erro meu desta etapa (no caderno, não esconder):** eu adicionei
`_auto_passa_espera` com o valor inicial `-1.0` (contagem desligada) e nunca o
liguei ao parsear a flag — a primeira foto saiu com `perspectiva 0` e a prova
não existia. A segunda tentativa pegou. E o primeiro teste da troca afirmava
que o "lado de cima" era o **Z maior**: no mundo 3D o topo é o Z **menor**
(mais longe da câmera), então o teste é que estava errado; a trava real passou
a ser pela **tela** (a carta sobe: `unproject_position`).

**O que a etapa 2 NÃO tocou (é da etapa 3 e 4):** as duas mãos
(`_pos_mao_arco`/`_y_da_mao`/`_passo_mao`), a compra, a fila de fusão, a carta
ao centro, o ataque, e o cursor escondido na vez do rival. Por isso a foto da
vez do rival ainda mostra **a sua mão embaixo** e a mão do rival em cima: é o
comportamento antigo, e a etapa 3 é justamente a que conserta.

---

## 16.14 A ETAPA 3 — as mãos (2026-09-29)

**O que o usuário pediu:** "a mão de baixo está muito desalinhada comparada
com a de cima", olhando a foto da etapa 2.

**O que a etapa 2 tinha deixado:** as mãos **não tinham sido tocadas** (elas
são a etapa 3), então não era regressão. E a geometria da mão de baixo estava
certa: as 5 cartas com a mesma largura e o mesmo topo (medido na foto: topo em
y=870 nas cinco). O que era realmente o problema: na vez do rival a mão de
baixo continuava sendo a **do jogador**, grande e aberta, enquanto a de cima
era a do rival, pequena e virada — as duas mãos com cara completamente
diferente na mesma tela.

**A correção (D7/D9, que já estavam decididas):** a mão de **baixo é a de quem
está jogando** e a de **cima é a do passive, sempre virada**. A sua só sai
**aberta**; a do rival é de costas nos dois lugares. E a mão é a única coisa
que **desliza** na troca (D9): a que estava embaixo sobe para o topo e a de
cima desce para baixo, cada uma no arco do dono e no mesmo índice — o resto
(campo) continua sem viajar, só esmaecendo (D3).

**Ganho extra, como o doc previa:** com a mão de cima sempre virada, a ordem
das cartas dela não vaza informação, então **o caso especial do D45 item 8
morre** (a 5ª posição da mão do rival espelhada). A mão parou de ter duas
regras e passou a ter uma.

**Prova:**

- **Duas fotos** de novo: `e5_sua_vez.png` e `e5_rival.png` (+ o lado a lado
  `e5_COMPARA.png`). Na vez do rival a mão de baixo é a **dele, virada**, e a
  sua foi para o topo, também virada. Mais `e5_rival.png` com
  `perspectiva 1` no log.
- **GUT:** o arquivo foi de 9 para **10 testes / 185 asserts** (o (10) mede a
  cara e o dono das duas mãos nos dois turnos, e que a volta é reversível),
  sabotado e pego; suíte **177/177, 3870 asserts, 0 SCRIPT ERROR, 0
  orphans**.
- **Três testes antigos precisaram mudar**, e a mudança é instructive: eles
  achavam "a carta da sua mão" pelo meta `mao_idx`, e agora **as duas mãos têm
  `mao_idx`** (o índice dentro da mão do seu dono). Passaram a filtrar por
  `mao_lado == 0` (a de baixo = a de quem joga). Sem isso eles mediam a mão
  ERRADA e acusavam a carta virada de não ter orbe/estrela — que é
  exatamente o que uma carta virada tem que não ter. O `mao_lado` é o meta
  que torna a mão inequívoca.

**Erro meu desta etapa (no caderno, não esconder):** a primeira foto da etapa
3 mostrou as cartas da mão de baixo com o **interior cinza** (a frente vazia)
em vez do verso. Causa: `rotation_degrees` substitui os TRÊS eixos, e a linha
que punha a inclinação da mão (`TILT_MAO_LIVRE`) estava sobrescrevendo o giro
de 180° que `_fazer_carta` põe na carta virada. Antes isso não aparecia porque
a mão de baixo nunca era virada (ela era sempre a do jogador, aberta); com a
etapa 3 ela passa a poder ser a do rival. Corrigido colocando a virada dentro
da mesma expressão da inclinação.

# 16 — PONTO DE VISTA DA MESA

> O que a tela do duelo mostra e de onde ela olha. Leia antes de mexer em
> `astralis/duel3d/vista_3d.gd` ou em qualquer coisa que anime a mesa.
> As regras aqui são D47, D51, D52, D53, D76 e D75; o porquê de cada uma está no
> `DECISOES.md` e não se repete.

## 16.1 A REGRA

A tela é a visão de **quem está jogando**, e a troca de lado é a **câmera** girando
180° em torno do centro do campo.

- O **pivô** é um nó que tem a câmera como filha. A câmera **nunca se move nem
  gira** — quem gira é o pivô. Não existe `look_at` por quadro: a inclinação vem
  da **rotação local** da câmera dentro do pivô.
- O número que manda em tudo é `giro_campo`: `0` = visão do jogador, `180` = do
  rival. **Não há segunda cópia** dele; a câmera, o HUD e as animações leem o
  mesmo.
- **As cartas do campo não se mexem.** `players[lado]["monstro"][i]` é a mesma
  carta antes e depois da volta. Nada teleporta, nada esmaece, nenhuma carta
  troca de lugar.
- **Não existe "coluna espelhada" como regra.** Ela sai de graça: o lado 1 da
  arena já vem espelhado no X (D18) e a volta espelha de novo, então cada
  jogador vê a **própria** fileira na ordem normal (índice 0 à esquerda).

O porquê de mexer nas cartas por perspectiva ser o caminho errado: é mais código
para o mesmo resultado, e a troca de lado vira espelho.

## 16.1.1 A MESA NASCE NA VISTA DE QUEM TEM A VEZ

Quem tem a vez é quem se vê, **inclusive no primeiro quadro**. A tela monta o
duelo depois do motor decidir, e a decisão dele é o número que manda: quando o
rival começa, a mesa é **colocada** na vista de 180 antes de qualquer quadro
passar, pelo mesmo `giro_campo` e pelo mesmo `ao_virar` da volta — sem tween.

**Não é pular a volta.** Na troca de vez do meio do duelo a volta é obrigatória e
continua passando por `girar_para`. No boot não existe volta porque nunca houve um
lado anterior: a mesa sempre esteve, e desde o primeiro quadro, na vista de quem
joga. Girar até lá mostra a perspectiva de quem **não** está jogando enquanto o
rival já compra e joga por baixo dela, e a tela mente sobre o dono do turno no
primeiro segundo do duelo.

| Momento | Quem manda | Como a vista é posta |
|---|---|---|
| o boot, com o rival começou | o `current_player` do motor | `colocar_vista(180)` na vista, sem tween |
| a troca de vez do meio do duelo | o START | `girar_para(180)`, com a volta inteira |

Quem coloca é a vista (`colocar_vista`) e quem chama é a mesa
(`_iniciar_turno_do_duelo`), porque ela é a que sabe o que o motor devolveu.

## 16.2 O QUE A CORREÇÃO PRECISA CONTINUAR SATISFEZENDO

A vista do rival é o **espelho exato** da sua, e isso é medido, não estimado.

**A causa do erro:** o pivô está na origem, mas o campo não é simétrico em
relação a ela. O plano de simetria é a média das duas fileiras de monstro da
arena oficial, e ele está em `z = -0,398` (as fileiras da arena são simétricas
em torno de `y=500`, e o `CENTRO_Y` do código é 540). Girando 180° em torno da
origem, a câmera do rival chega `2 x 0,398 = 0,796` **perto demais** da mesa, e
o campo sai 57 px mais baixo.

**A correção, tirada do dado:**

```text
medir_plano_de_simetria()   # z_simetria = média das 10 posições de monstro, 1x
_z_local_da_camera(giro)    # cam_pos.z - 2 * z_simetria * (giro / 180)
```

Em `0` isso dá `cam_pos.z` **exatamente** — a visão do jogador é a de sempre. Em
`180` a câmera recua os 0,796 e cai no espelho exato: as duas fileiras ocupam o
mesmo retângulo de tela, com as de cima e de baixo trocadas, e o vão entre elas
é o mesmo número.

A rotação local da câmera **não** é tocada (a inclinação continua vindo de
`CAM_POS`), o FOV não muda e `frustum_offset` continua ZERO.

**Duas proibições que o usuário mesmo colocou:**

- A **faixa 2D do meio não se mexe**. Ela não ganhou nenhum código de
  reposicionamento por vista, e não pode ganhar.
- A **visão do jogador não muda em nada**. `CAM_POS`, a rotação e o
  `frustum_offset` ficam intactos; a correção tem de estar em 0° exatamente como
  estava.

## 16.3 O HUD 2D VIRA DE CARTA

O HUD não gira. Ele encolhe no eixo X com `abs(cos(graus))` — `1` em 0° e 180°,
`0` em 90° — e o conteúdo troca **exatamente nos 90°**, quando a largura é zero
e ninguém vê a troca.

**Invertem** na virada: os retratos, as plaquinhas de nome e de LP, e a ordem
das 7 células da faixa do meio. A cor viaja com o número, então azul continua
sendo você.

**A barra de fases NÃO inverte**, de propósito: ela mostra a fase **real** de
quem está jogando, e espelhar um dado de regra seria a tela mentir.

O dono disso é `vista_3d.gd`, em `escala_do_virar()` e `invertida()`; a mesa
aplica o resultado em `_aplicar_vista_hud()`.

## 16.4 AS DUAS MÃOS

- **Quem está jogando ocupa o lugar de BAIXO** e o outro o de CIMA.
- Na vista do rival **cada lugar é o espelho do mesmo lugar** na sua vista. Como
  as duas vistas já são espelhos uma da outra, nenhuma medida teve de ser refeita
  quando essa regra entrou.
- O **Y e o X não mudam** entre as vistas. Os lugares são `LUGAR_PERTO_YZ` e
  `LUGAR_LONGE_YZ`; perto é 8,2 unidades da câmera nas duas vistas, longe é
  27,35 — ou seja, **o mesmo tamanho de carta na tela** dos dois lados.
- A troca acontece nos **90°**, que é o instante em que a tela não mostra nada.
- **Na vista do rival as duas mãos ficam de pé** e mostram o verso. O motivo: o
  verso de uma carta não é o espelho da frente dela, então virar de cabeça para
  baixo mostraria a arte do jogador em vez do verso.
- **O cursor some na vista do rival.** Ele fica preso na carta da sua mão e, com
  as mãos trocadas, ficaria em cima da mão do rival denunciando a sua escolha.

**O que continua travado da D47:** as cartas do **campo** não se mexem. A D52
reabriu só as mãos.

**Armadilha já paga uma vez:** `_y_da_mao` e `_x_centro_da_mao` são resolvidos
uma vez e valem para as duas vistas, porque a câmera é a mesma instance nos dois
lados. Memorizar por `instance_id` da câmera e resolver na vista do jogador dá
errado quando o **rival** começa o duelo — por isso `_aquecer_a_mao()` resolve
os dois lugares no boot, antes de qualquer carta ser desenhada.

## 16.5 A COMPRA DE CADA UM (D76)

A entrada da carta comprada é um assunto só, e ele mora em
`astralis/duel3d/entrada_mao_3d.gd`. São **dois** movimentos no mesmo instante:

1. a(s) carta(s) que comprou **voa** do baralho até o lugar novo, em arco,
   tombada, entrando menor e assentando com um pastelhinho de escala a mais; e
2. as que já estavam na mão **deslizam** para o lugar novo delas.

**Por que as duas:** a mão é centrada, então comprar uma carta muda o lugar de
**todas** as outras. Sem o deslize elas aparecem no lugar novo de um quadro para o
outro, e é esse salto — não o voo — que faz a compra parecer quebrada. Uma compra
pode trazer duas cartas, e elas saem **escalonadas**: é o que faz parecer que
alguém está repartindo, em vez de um bloco só.

**A entrada é de quem comprou, e só da carta que comprou.** O dono vem da mesa
(é ela que sabe de que mão é a compra), e a carta nova é a que apareceu depois do
tamanho de mão do desenho anterior.

**A compra só é mostrada depois que a câmera parou na perspectiva de quem
comprou.** O motor troca o jogador e compra na **mesma** chamada de fase, então
o tempo da compra é escolhido pela mesa: `_passar_turno` avança só até o `END` do
jogador, dá a volta, e **só então** entrega a vez. E o dono da tela para a volta
de volta também espera, antes de abrir o fluxo do jogador.

O **tempo do voo é do arquivo da entrada**, e quem espera a mão assentar lê
dele (`EntradaMao3D.duracao_total`): um teto escrito no chamador seria a segunda
fonte da mesma medida, e o corte apareceria como a carta parando no ar.

## 16.6 UM DESENHO QUE SE MEXE SEM PRECISAR

Três defeitos da mesma família, e as três travas:

| O que | A regra |
|---|---|
| A compra animada | É da mão **que comprou** e só da carta que comprou; as outras deslizam, e nada acontece antes de a câmera parar na perspectiva de quem comprou (16.5). |
| A chacoalhada da fusão | É da **carta do slot**, e nunca sacode a mesa inteira. A trava está **dentro** de `_sacudir`, para ninguém reintroduzir. |
| O passo de cursor | Só reposiciona o cursor e o painel. `_redesenhar` recria as 20+ cartas e é caro; chamá-lo a cada tecla redesenhava a tela 3D inteira. |

**Regra de teste que acompanha as três:** a entrada da mão e o `_sacudir`
perderam a trava de "só com render" **de propósito**. Sem ela o teste passava e o
defeito ficava invisível; com ela removida, o GUT **vê quem animou**.

## 16.7 ONDE VIVE CADA COISA

| Assunto | Dono |
|---|---|
| câmera, pivô, `giro_campo`, `z_simetria`, `girando`, `girar_para()`, `colocar_vista()` | `astralis/duel3d/vista_3d.gd` |
| `CAM_POS`, `VOLTA_DURACAO`, `ESCALA_CAMPO`, `DESLOC_CAMPO`, janela do SubViewport | `astralis/duel3d/mesa_3d.gd` (a vista **recebe** esses números) |
| traduzir slot do dado em XZ de mundo | `mesa_3d.gd`, em `pos_slot` (passado por `Callable` para a vista) |
| lugar das mãos, pose, arco, aquecimento no boot | `mesa_3d.gd`: `_dono_do_lugar_perto`, `_pose_da_mao`, `_pos_mao_arco`, `_aquecer_a_mao` |
| de quem é a compra, quantas cartas entraram e de onde elas saem | `mesa_3d.gd`: `_preparar_entrada`, `_marcar_entrada`, `_tocar_entrada` |
| o trajeto, o escalonamento e o TEMPO da entrada na mão | `astralis/duel3d/entrada_mao_3d.gd` |
| orquestrar mão e HUD a cada passo da volta | `mesa_3d.gd`: `_aplicar_vista_da_mao_entao_hud` |
| a porta que o START e os testes chamam | `mesa_3d.gd`: `_girar_campo(alvo)` |
| quando a vez é entregue (e a compra com ela) | `mesa_3d.gd`: `_passar_turno` e `_rival_auto` esperam a volta **antes** de `_redesenhar(true, dono)` |
| colocar a mesa na vista de quem tem a vez, no boot | `mesa_3d.gd`: `_iniciar_turno_do_duelo` chama `colocar_vista` na vista |

A vista **não** conhece a mão nem o HUD: a cada passo ela chama `ao_virar`, e a
mesa aplica os dois assuntos na ordem da D52.

`aplicar()` é o **único** dono do 3D na volta — pivô e câmera saem do mesmo
`giro_campo`, e ninguém ajusta o pivô por conta própria.

## 16.8 O QUE NÃO PODE

- **Não deslocar a câmera** e **não mexer em `frustum_offset`**. Deslocar a lente
  achata um lado e estica o outro. Se parecer torto, muda o retângulo do
  SubViewport (doc 15), nunca a câmera.
- **A trava é da câmera do CAMPO.** O painel esquerdo tem a janela 3D dele, com
  a câmera dele, e ela é ortogonal de propósito (doc 15 §15.9): olho de painel
  não é olho de mesa. O que não existe é deslocar ou entortar a lente **do
  campo**.
- **Não guardar o ponto de vista em variável de estado.** Ele vem do dono da vez
  a cada quadro (R1); guardar é a forma de a tela mentir.
- **Não espalhar o "de que lado eu desenho"** por cada animação. A troca das
  mãos passa por `_aplicar_vista_da_mao_entao_hud`, e é um lugar só.
- **Não dar à mão uma segunda cópia do número da vista**, nem resolver a pose de
  uma vez e lembrar (ver 16.4).
- **Não existe pular a volta.** Na troca de vez do meio do duelo ela roda sempre
  inteira, e o controle fica travado enquanto ela gira.
- **Não nascer na vista de quem não tem a vez.** A mesa não pode aparecer na sua
  perspectiva e girar depois quando o rival começou: no boot a vista é *colocada*
  (`colocar_vista`), e a volta continua sendo só da troca de vez (ver 16.1.1).
- **Não entregar a vez antes de a volta acabar**, nem por volta de lado: a compra
  de cada um é mostrada na tela de quem comprou (ver 16.5).

## 16.9 MEDIR


**Meça em unidades de mundo, por código, nunca por pixel de foto.** A volta da
mesa faz o mesmo intervalo de mundo aparecer com 276, 257 e 220 px na tela
(proporção, não erro), então o pixel não é medida.

- `python tools/checar_docs.py` não diz nada de vista; o que trava é o GUT.
- As flags de prova do jogo são `--mesa3d-foto-frame=N`, `--mesa3d-auto-passa=s`
  e `--mesa3d-calib` (doc 15).
- A volta é travada por `astralis/testing/test_volta_mesa.gd`, que fala com o
  **nó** da vista por um helper, nunca por dentro da mesa.
- A vista do primeiro quadro é travada por
  `astralis/testing/test_turno_quem_comeca.gd`, que **força o caminho com
  render**: sem render a volta pularia direto para 180 e o defeito seria
  invisível para o teste.
- A compra cair só depois da volta é travada por
  `astralis/testing/test_volta_mesa.gd`, que passa o turno de verdade e olha o
  giro da câmera e o tamanho da mão **a cada quadro**.
- A entrada terminar no lugar é travada por
  `astralis/testing/test_compra_fila.gd`, para os **dois** lados: medir no
  primeiro quadro não prova nada, porque a carta começa no baralho de propósito.

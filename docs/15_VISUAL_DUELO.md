# 15 — VISUAL DA MESA DE DUELO (espelho da referência)

VERSION: 1.9 (D45: a faixa do meio virou 2D; START/HELP fora; retratos no alto)
STATUS: AUTHORITATIVE (contrato visual, owner: lead)
ORIGEM: pedido do usuário 2026-09-28 — "deixar o visual do nosso duelo idêntico a essa imagem"
REFERÊNCIA: `C:\Users\Max\Downloads\Screenshot-2021-05-05-214047-e1620266990864.webp` (1024x583)
ESCOPO: **SÓ O DESENHO.** Nenhuma mecânica de duelo muda (R1).

## 15.0 D45 — a leva de correções do usuário (2026-09-28)

Oito pedidos do usuário depois de jogar, todos de DESENHO:

| # | Pedido | Onde mora |
|---|---|---|
| 1 | Retratos bem na beirada de cima, mesmo espaço nas 3 laterais, e o bloco de nome com o TOPO na MESMA LINHA do topo da foto | `RETRATO_MARGEM` (14 px) + `RETRATO_*_Y` + placa de nome no mesmo `y` |
| 2 | A faixa do meio (deck/cemitério/LP/turno) **virou 2D** no vão entre as fileiras | `HUD/Faixa2D` (§15.7) |
| 3 | Blocos **limpos**: sem as palavras (DECK, CEMITÉRIO, SEU LP, TURNO, LP RIVAL) e sem ícone de pilha | `_celula_faixa_2d` só tem número + foto |
| 4 | Todo número da faixa em **branco** | `FAIXA2D_COR_NUM` |
| 5 | Cor do **cemitério**: borda preta (que não é preta escura) e interior preto mais claro | `COR_PRETO_BORDA` / `COR_PRETO_FUNDO` |
| 6 | **Foto da última carta do cemitério** num quadrado perfeito: ponta esquerda no seu, ponta direita no do rival | `_carta_do_cemiterio` + `_arte_real` + `Caixa/Arte` |
| 7 | A célula do **turno** alterna a cor com quem está jogando (azul = você, vermelho = rival) | `_tingir_turno` (lê `current_player`) |
| 8 | A carta comprada entra sempre na 5ª posição: você à direita, o rival pela esquerda (ele joga do outro lado da mesa) | arco do rival ESPELHADO em `_pos_mao_arco` |
| 9 | A mão do rival entre o topo da tela e o topo dos slots de magia dele | `_y_da_mao` (altura resolvida da câmera) |
| 10 | Sua mão colada na linha de baixo da sua fileira de magia | idem (topo da carta = base da fileira + 5 px) |
| 11 | Espaço entre as cartas da sua mão (não podem se atravessar) | `MAO_P0_PASSO` = 1,08 (> 1,0 = vão de verdade) |
| 12 | "START ? Help" fora da tela | removido; a ação continua no joypad (D19) |

**Por que a faixa foi para 2D (§15.7).** Em 3D, a posição de um objeto no chão
é a soma de três números que precisam concordar (o z da fileira, metade da
profundidade do ladrilho e a profundidade do próprio objeto), e "a altura do
chão" na tela é uma **faixa** (o ladrilho é um plano visto de lado), não uma
linha. Era por isso que a base entrava e saía do lugar a cada ajuste. Em 2D a
posição é o pixel: uma linha, um número, e dá para fazer bonito de verdade.

**Ferramenta de conferência visual (novo, D45).** Ligar com
`--mesa3d-calib=1`: a tela ganha um quadrado vermelho grande com a **linha de
cima na altura dos slots** (tudo que entrar dentro dele está afundado na
mesa) e as linhas das outras fileiras com o nome e o valor em pixels. Só
desenho, zero regra, e fora disso a tela fica limpa.

## 15.1 O que muda e o que NÃO muda

MUDA (desenho): enquadramento da câmera, posição do campo na tela, aparência dos
painéis de vidro, aparência das cartas, barra de LP/turno, painel lateral de
informação, contador de deck, moldura de foco, START/Help, mão.

NÃO MUDA (regra — é do motor, em `astralis/duel/`): zonas 5+5, ordem das fases
FM (DRAW/MAIN/BATTLE/END), mão 5 + refill, invocação, ataque, dano, fusão, menu
da estrela, IA do rival, vitória/derrota, controle 100% joypad (D19).

> **Conflito conhecido com a referência:** a imagem é do Tag Force e mostra a
> barra de fases `DP SP MP1 BP MP2 EP`. Nosso duelo é Forbidden Memories, que
> **não tem essas fases** (foram removidas por ordem do usuário em 2026-09-28).
> A barra continua existindo com o MESMO visual metálico, mas o conteúdo é a
> fase REAL do motor. Mostrar DP/SP/MP1/BP/MP2/EP seria inventar mecânica.

## 15.2 Fonte de cada imagem (R1/R3 — nada inventado no duelo)

| Elemento na tela | De onde vem | Status |
|---|---|---|
| Arte da carta (ilustração) | `card.artwork` do pack (dado) | 722 PNGs 408x384 existem |
| Moldura da carta | `assets/frames/{normal,effect,spell,trap,ritual,fusion}.jpg` | 6 JPGs originais do usuário (D38, PROIBIDO editar) |
| Orbe do atributo | `assets/attributes/<attribute>.png` | 9 PNGs |
| Estrelas do nível | `assets/estrelas/estrela.png` (repetida = `level`) | 1 PNG |
| Verso (carta virada) | `assets/backs/verso_padrao.png` / `card_back` da carta | 1 PNG |
| Nome, tipo, ATK/DEF, descrição, tipo de monstro | dado do pack (texto) | description do FM é `""` (结构性) |
| Retrato do duelista | `duelist.portrait` do pack | dado |
| Nome do duelista, LP, turno, fase | estado REAL do `GameState` | dado em tempo real |

**Regra dura:** o duelo NUNCA escreve nome/ATK/DEF/atributo/nível hardcoded.
Vem sempre do estado real. Se falta arte, mostra placeholder cinza (doc 09.4) —
nunca inventa.

**Onde esses arquivos moram (decisão Lead 2026-09-28):** o jogo tenta primeiro o
PROJETO (`--project`, via `_base_dir`); se não achar, cai no **embutido do
jogo** em `astralis/assets/` (mesmos caminhos `assets/frames/...` etc.). O
código já faz essa cascata, só faltavam os arquivos. O Studio continua com os
seus em `astralis-studio/static/` — as duas cópias são **byte-idênticas** e um
teste de compatibilidade (padrão já usado em `test_card_layout.gd`) trava isso,
para o editor e o jogo nunca divergirem.

## 15.3 Medições da referência (medidas na imagem, 1024x583)

Tudo em % da largura/altura da tela. Sirvem de alvo; o ajuste fino é por
comparação de screenshot até bater.

```text
PAINEL ESQUERDO (2D):   x 0,0% .. 29,3% (0..300 px)   altura toda
  carta focada:         x 1,5% .. 29,5%   y 1,5% .. 52%
  ATK/DEF + 2 orbes:    y 52% .. 60%, alinhado à esquerda
  contador "x4":        y 55% .. 60%, à direita
  NOME (amarelo):       y 62% .. 70%
  TIPO (verde):         y 70% .. 74%
  DESCRIÇÃO (branco):   y 75% .. 100%, barra de rolagem laranja na direita
BARRA SUPERIOR (2D):    x 29,3% .. 100%   y 0 .. 8,6%
  placa azul esq (LP/nome): x 30,7% .. 50% ; aba "Single" abaixo
  caixa central TURN:      x 62% .. 76%
  placa vermelha dir:      x 76% .. 100%
CAMPO 3D (vidro):       x 29,3% .. 100% (o trapézio encosta na borda direita)
  fileiras (de cima p/ baixo): magia rival, monstro rival, [barra de fases], monstro meu, magia minha
  centro do campo:       x ~63,5% da tela (NÃO no meio) — é o ponto do conflito
  painéis: vidro azul escuro translúcido, mais largo embaixo, afunila p/ cima
RETRATOS (2D):          jogador x 31%..40% y 6%..15% ; rival x 92%..99% y 6%..15%
CONTADOR DE DECK:       "36" x 40%..46% y 24%..30% (placa escura inclinada)
                        "3"  x 84%..89% y 24%..30%
ÍCONES LATERAIS (2D):   coluna x 31%..39% y 32%..48% ; coluna x 85%..94% y 32%..48%
FOCO:                   retângulo azul brilhante em volta do painel escolhido,
                        com a mão branca (cursor) no centro
MÃO:                    y 78% .. 100%, cartas em arco leve, de pé, cortadas embaixo
START / Help:           x 84%..98% y 96%..100%
```

## 15.4 O problema da perspectiva — e a solução (o ponto crítico)

**O problema:** para colocar o campo à direita da tela, a tentativa anterior
moveu a LENTE (`CAM_OFFSET_X = 0.16` em `mesa_3d.gd`). Isso é uma projeção
*fora do eixo*: o lado direito da tela é esticado e o esquerdo comprimido, e
tudo fica com cara de torto. Não adianta aumentar a tela — o problema é a
matemática, não o tamanho.

**A solução: não move a câmera. Move a JANELA.**

O mundo 3D é renderizado num `SubViewport` que ocupa só a região do campo
(x de 29,3% até 100% da tela). A câmera fica **exatamente como está hoje** —
olhando o centro do campo, sem deslocamento nenhum. Depois o resultado é
exibido nessa região, e a tela toda é dividida assim:

```text
+----------------+--------------------------------+
|                |                                |
|  PAINEL 2D     |   SubViewport 3D              |
|  ESQUERDO      |   (câmera CENTRADA, sem       |
|  0%..29,3%     |    deslocamento = perspectiva |
|                |    igual à de "no meio")      |
|                |        centro do campo        |
|                |        = 64,6% da tela  ✓     |
+----------------+--------------------------------+
        HUD 2D por cima de tudo (barra de LP/turno, foco, START/Help)
```

Porque a câmera não muda, a perspectiva é **idêntica** à de quando o campo
está no meio — por construção, não por ajuste. O centro do campo cai em
29,3% + 70,7%/2 = **64,6%** da tela; na referência ele está em ~63,5%.
Batemos quase de graça.

**O que o mundo 3D ganha:** o céu/cidade e os pilares de vidro passam a existir
só na região do campo. O painel 2D esquerdo ganha o fundo escuro dele, como na
referência. Isso é o efeito colateral Aceito.

**Proibições desta fase:** NÃO usar `frustum_offset`, NÃO deslocar a câmera em
X, NÃO mover o campo no mundo para "empurrar" para a direita, NÃO aplicar
escala/rotação na textura do SubViewport. Se parecer torto, a solução é
mudar o retângulo do SubViewport, nunca a câmera.

## 15.5 Fases de execução (cada uma com PROVA de screenshot)

| Fase | Entrega | Portão | Estado 2026-09-28 |
|---|---|---|---|
| 1 | SubViewport + câmera intacta + campo à direita (15.4) | screenshot com o campo em ~64,6%, perspectiva simétrica | **FEITA** — 64,64% medido, simetria exata nas 4 fileiras |
| 2 | Campo com a cara da referência: vidro escuro translúcido, trapézio, ordem das fileiras, cartas deitadas com a CARTA REAL | screenshot do campo isolado | **FEITA** — desvio máx 3,6% de altura; largura encostando na direita (99,9%) |
| 3 | HUD 2D: barra de LP/turno, painel esquerdo completo, contadores, moldura de foco, START/Help | screenshot da tela cheia | **FEITA** |
| 4 | Mão no estilo da referência + cursor/joypad batendo | screenshot + GUT | **FEITA** |
| 5 | QA: testes que travam o enquadramento e a perspectiva | GUT verde | **FEITA** — 136 testes / 3275 asserts / 0 falha |
| 6 | Polimento: moldura de foco, carta de DEF dentro do ladrilho, mão do rival, contadores, linha "LUZ", moldura do retrato | 2 fotos (mão + campo) | **FEITA** — commit `b4041cc` |

Ponto de restauração anterior a tudo isso: branch `antes-visual-tagforce` +
tag `restaurar-antes-tagforce` (commit `fd89783`).

### Decisões que arose no meio (não reabrir sem o Lead)

- **A câmera pode livremente mudar** (posição Y/Z, altura, FOV). A tríade que
  garante a perspectiva simétrica é: `CAM_POS.x == 0`, alvo no centro do campo
  e `frustum_offset == Vector2.ZERO`. Mover a câmera NÃO é o problema de
  perspectiva — o deslocamento de lente (frustum) que era.
- **O campo tem transform de apresentação** (`ESCALA_CAMPO` + `DESLOC_CAMPO`):
  escala uniforme + deslocamento aplicado ao layout da arena. A arena continua
  mandando na composição e no espelho (D17/D18); o transform só muda o tamanho
  e a posição na janela. Não se pode usar escala não-uniforme (quebra a
  perspectiva do trapézio) — há teste.
- **Assets embutidos no jogo**: `astralis/assets/` tem as 6 molduras, 9 orbes,
  a estrela e o verso, byte-idênticos ao `astralis-studio/static/`. O jogo
  tenta o projeto primeiro, cai no embutido. Teste de compatibilidade Studio x
  jogo trava os 17 (SHA-256). Motivo: sem isso o jogo nunca mostra a carta
  real sozinho.
- **A aba "Single" foi removida**: era texto inventado; nosso contrato não tem
  modo de duelo declarado (R3).

### O que NÃO pode ficar igual à referência (falta dado, não falta código)

1. **Retratos dos duelistas**: os 39 duelistas do FM têm `portrait` vazio e o
   pack não traz imagem. Fica placeholder com moldura. Para igualar, o pack
   precisa das 39 fotos.
2. **Descrição das cartas**: as 722 do FM vêm com `description: ""`. O painel
   mostra a área de texto (com barra de rolagem) mas vazia. Para igualar, o
   pack precisa das descrições.
3. **Cidade do fundo**: a referência tem uma cidade 3D; aqui é céu procedural
   com gradiente. Não há imagem de fundo no pack. Decisão pendente do usuário:
   usar uma imagem de fundo ou manter o céu.
4. **Barra de fases**: mostra DRAW/MAIN/BATTLE/END (§15.1), não DP/SP/MP1/BP/MP2/EP.


## 15.6 Ferramenta de prova

O jogo já sai com `-- --mesa3d-foto=<caminho.png>` (salva o viewport e sai)
e com `--mesa3d-calib=1` (liga o quadrado de calibração do §15.0). É o jeito de
olhar a tela real e comparar com a referência. Usar em toda fase.

Para a arte aparecer, o jogo precisa de um projeto com os assets: dá para
apontar `--project` para uma cópia descompactada do
`studio_pack_20260925_180627_COMPLETO.apack` (722 cartas, 59 MB, tem as artes).
Isso é sonda de desenvolvimento em pasta temporária, não vai para o repo.

## 15.7 A faixa do meio em 2D (D45, item 2)

A faixa continua no MEIO da tela, entre a fileira de monstros do rival e a
sua, mas agora é **2D** (filha do HUD, por cima do campo 3D). Sete células na
ordem que o usuário ditou (D44; em D45 o **cemitério e o baralho trocaram de
lugar**):

```text
[ FOTO 2 ][ DECK 40 ][ SEU LP 8000 ][ TURNO 1 ][ LP RIVAL 8000 ][ DECK 35 ][ 1 FOTO ]
```

- **Deck**: só a CONTAGEM de cartas do baralho real.
- **Cemitério**: a CONTAGEM + a **FOTO da última carta que foi para lá**, num
  **quadrado perfeito** preenchendo a ponta **esquerda** (a sua) ou
  **direita** (a do rival). É um *corte* quadrado da arte real (a imagem nunca
  distorce) e vem pelo cache de textura. Cemitério vazio = sem foto (nunca
  uma imagem inventada).
- **LP e turno**: número do GameState real, sempre **branco**. A célula do
  **turno muda de cor com quem está jogando** (o `current_player` do motor):
  azul na sua vez, vermelho na vez dele.
- **Sem palavra e sem ícone** dentro dos blocos (D45, item 3): a informação
  sozinha, com a plaquinha identificada pela cor.
- **Três conjuntos de cor**, cada um com borda escura e interior mais claro:

| Conjunto | Borda | Interior | Onde |
|---|---|---|---|
| azul | `COR_AZUL_BORDA` | `COR_AZUL_FUNDO` | seu deck, seu LP, bloco do **seu nome** (topo), turno na sua vez |
| vermelho | `COR_VERM_BORDA` | `COR_VERM_FUNDO` | deck e LP do rival, bloco do **nome do rival** (topo), turno na vez dele |
| preto | `COR_PRETO_BORDA` (preto que não é preto escuro) | `COR_PRETO_FUNDO` (preto mais claro) | os **dois cemitérios** |

- **Posição**: medida, não chutada. O vão vem das bordas REAIS das duas
  fileiras de monstros (`_borda_da_fileira_px`, dado + câmera) e a largura vem
  da extensão real da fileira (`_extensao_da_fileira_px`). A barra é
  **centrada no vão** e nunca invade nenhuma das duas fileiras.
- **Zero regra** (R1/R3): a faixa só lê o estado. O `Campo/Faixa` 3D do D44
  foi REMOVIDO por inteiro (pilhas, placas, fatias de carta, `_construir_faixa`).

O que essa faixa **não** é: não é o tabuleiro, não calcula nada, e o Godot
continua sendo o dono de LP, compra, descarte e vitória.

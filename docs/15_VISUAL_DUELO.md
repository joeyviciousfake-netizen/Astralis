# 15 — VISUAL DA MESA DE DUELO

> O contrato visual da mesa: o que é medido, de onde vem cada imagem, e quem é o
> dono de cada número do desenho. **Escopo: só desenho.** Nenhuma regra de duelo
> muda aqui (R1). As decisões são D37, D38, D41, D45 e D70; o porquê de cada uma
> está no `DECISOES.md`.

## 15.1 O QUE MUDA E O QUE NÃO

**Não muda** (se mexer aqui, você quebrou regra): as zonas 5+5, a ordem das fases,
a mão 5 com refill, a invocação, o ataque, o dano, a fusão, o menu da estrela, a
vitória e a derrota, e o controle 100% por joypad (D19).

**A barra de fases mostra a fase real do motor** (`DRAW/MAIN/BATTLE/END`). As
mesas de fase da referência não existem no nosso duelo; mostrá-las seria inventar
mecânica.

**A tela não tem barra de "START ? Help".** A ação continua no joypad (D19), e a
mesa tem um comentário que registra isso.

## 15.2 DE ONDE VEM CADA IMAGEM (R3 — nada é inventado)

| O quê | De onde |
|---|---|
| 6 molduras de carta | `astralis/assets/frames/`, byte-idênticas ao `static/frames/` do Studio (D38) |
| 9 orbes de atributo | `astralis/assets/attributes/` |
| estrela de nível | `astralis/assets/estrelas/` |
| verso da carta | `astralis/assets/backs/` |
| arte da carta | `artwork` do dado; 722 PNGs em `schemas/examples/assets/fm/` |
| retrato do duelista | `portrait` do dado; **vazio no pack do FM** → placeholder cinza |
| fundo do tabuleiro | gerado em código, sem imagem |

A cascata é: projeto (`--project` → `_base_dir`) → embutido em `astralis/assets/`
→ Studio em `astralis-studio/static/`. Os 17 pares embutidos são comparados por
**SHA-256** em `astralis/testing/test_assets_embutidos.gd`, e sabotar 1 byte faz
o teste falhar.

**O duelo nunca escreve nome, ATK, DEF, atributo ou nível hardcoded.** Vem sempre
do estado real. Se falta arte, mostra placeholder cinza — **nunca inventa**.

## 15.3 A PERSPECTIVA (o ponto crítico, D41)

**Problema:** deslocar a lente achata um lado e estica o outro, então a
perspectiva fica torta na hora que o campo é puxado para a direita.

**Solução:** a câmera **não se desloca** e o campo é que ganha uma **janela**.

| Medida | Valor | Por quê |
|---|---|---|
| `CAM_POS.x` | `0` | a lente fica no eixo |
| `frustum_offset` | `Vector2.ZERO` | sem deslocamento de lente |
| `PAINEL_ESQ_L` | `562` px | o campo começa depois do painel 2D (29,3% da tela) |
| `JANELA_CAMPO_L` | `1358` px | 70,7% da tela — a janela do SubViewport |
| `ESCALA_CAMPO` | `1.23` | transform de apresentação, sobre o layout da arena |
| `DESLOC_CAMPO` | `Vector2(0.0, -0.07)` | idem |

O centro do campo cai em **64,6%** da tela, e a simetria nas 4 fileiras é exata.

**A tríade que garante a perspectiva simétrica:** `CAM_POS.x == 0`, alvo no centro
do campo e `frustum_offset == Vector2.ZERO`. Mover a câmera **não** é o problema;
o deslocamento de lente é que era.

**Proibições:**

- **Não** mexer em `frustum_offset`.
- **Não** deslocar a câmera em X.
- **Não** mover o campo no mundo.
- **Não** aplicar escala não uniforme — quebra a perspectiva do trapézio, e há
  teste para isso.

Se parecer torto, a solução é mudar o **retângulo do SubViewport**, nunca a
câmera.

## 15.4 MEDIÇÕES-ALVO DA REFERÊNCIA

São **alvos** de composição (em % da tela), não medidas do que existe:

| Região | Alvo |
|---|---|
| área do campo (SubViewport) | x 29,3%..100%, altura toda |
| painel esquerdo (2D) | x 0..29,3% |
| retrato | 7,5% de largura, margem igual nos 3 lados |
| nome do duelista | alinhado ao topo da foto |
| faixa do meio | entre as fileiras, no vão |

O que **não** pode ficar igual à referência é falta de **dado**, não de código: os
39 retratos dos duelistas, as 722 descrições das cartas, a cidade de fundo e a
barra de fases da referência.

## 15.5 FERRAMENTAS DE PROVA

| Flag | O que faz |
|---|---|
| `--mesa3d-calib=1` | quadrado vermelho com a linha de topo na altura dos slots: **tudo que entrar dentro dele está afundado** na mesa, mais as linhas das outras fileiras com nome e valor em pixel |
| `--mesa3d-foto=<caminho.png>` | grava a tela num PNG |
| `--mesa3d-foto-frame=N` | grava o quadro N da volta |
| `--mesa3d-auto-passa=s` | roda `s` segundos de duelo e tira a foto sozinho |
| `-- --debug` | diagnóstico por log (o log de boot é contrato e sai sempre, R11) |

Fora da flag a tela fica limpa. `--mesa3d-calib` foi o que mostrou o "afundado"
das placas sem depender de medir pixel por pixel.

## 15.6 A FAIXA DO MEIO (2D, D45)

A faixa do meio é **2D, no HUD**, dentro do vão entre as fileiras de monstros.

**As 7 células, na ordem:**

```text
[ FOTO | DECK | SEU LP | TURNO | LP RIVAL | DECK | FOTO ]
```

- **Deck**: só a contagem, sempre virado para baixo.
- **Cemitério**: contagem + a **foto da última carta** que foi para lá, num
  quadrado perfeito — à **esquerha** no meu, à **direita** no do rival. O corte é
  quadrado, a imagem nunca distorce. Cemitério vazio **não** mostra foto
  inventada.
- **Turno**: alterna a cor com quem está jogando (azul na sua vez, vermelho na do
  rival).
- **Todos os números são brancos**, e os blocos **não têm palavra nem ícone**:
  dentro de cada célula é só o número e, no cemitério, a foto.

**Três conjuntos de cor**, e o mesmo conjunto no bloco do nome do topo e no bloco
do LP daquele lado:

| Cor | Serve a |
|---|---|
| azul | você |
| vermelho | rival |
| preto (borda preta, interior mais claro) | os dois cemitérios |

**A posição é medida, não chutada.** O vão vem das bordas **reais** das duas
fileiras (`_borda_da_fileira_px`) e a largura da extensão real
(`_extensao_da_fileira_px`); a barra é centrada no vão e nunca invade fileira
nenhuma. O GUT trava as duas coisas.

O porquê de 2D: em 3D a base de um objeto depende de três números que precisam
concordar (z da fileira, meia profundidade do ladrilho, profundidade do objeto) e
a "altura do chão" na tela é uma faixa, não uma linha. Em 2D a posição é o pixel.

## 15.7 ONDE O DESENHO MORA: OS 8 ARQUIVOS

| Arquivo | Assunto | O que ele decide |
|---|---|---|
| `astralis/duel3d/mesa_3d.gd` | a mesa: orquestrador | o estado do duelo, o boot, o redesenho, e é o **dono das medidas** |
| `astralis/duel3d/vista_3d.gd` | a vista e a volta | câmera, pivô e `giro_campo` (doc 16) |
| `astralis/duel3d/campo_3d.gd` | o campo de vidro | onde os 20 painéis de vidro ficam |
| `astralis/duel3d/carta_3d.gd` | a fábrica de carta | corpo, arte, ATK e verso de uma carta 3D |
| `astralis/duel3d/cursor_3d.gd` | o cursor de foco | a moldura azul e a mão branca |
| `astralis/duel3d/faixa_2d.gd` | a faixa do meio | as 7 células, as cores e as fotos |
| `astralis/duel3d/painel_carta_3d.gd` | o painel esquerdo | molde, arte, ATK/DEF, nome, descrição |
| `astralis/duel3d/menus_3d.gd` | os menus 3D | o menu do LP e o da estrela |

**Três regras atravessam os oito (R9, D57):**

1. **Um arquivo = um assunto**, e o assunto manda na divisão — nunca a contagem,
   e nunca criar arquivo minúsculo só para existir.
2. **Número com um dono só.** Quem mede é a mesa; o assunto **recebe por parâmetro
   ou `Callable`** e nunca copia o número de outro. E o receptor **não tem
   default**: se a medida não chegar, ele nasce do tamanho zero e grita (D70).
3. **A UI nunca guarda cópia do estado.** Ela pergunta ao dono na hora de
   desenhar. Guardar cópia faz a tela mostrar turno velho depois que o duelo muda.

**Estado atual:** os oito cumprem a regra, menos a `mesa_3d.gd`, cujo
orquestrador ainda carrega assunto demais. A divisão pelo assunto é o resto do
trabalho (ver as dívidas no `SESSAO_ATUAL.md`).

## 15.8 A MEDIDA DA CARTA É A DO CONTRATO (D70)

Não é escolha de autor, é dado:

| Símbolo | Valor | De onde |
|---|---|---|
| `LARG_CARTA` | `1.0` | 59 mm, a largura real de uma carta |
| `ALT_CARTA` | `86.0 / 59.0` | 86 mm de altura |
| `GROSS_CARTA` | `0.30 / 59.0` | 0,30 mm de espessura |
| `RAIO_CARTA` | `2.0 / 59.0` | 2 mm de raio no canto |
| `SEGMENTOS_ARCO` | `8` | quantos lados o canto arredondado tem |

O 59 e o 86 são `const` em `schemas/card_layout.schema.json` (`canvas.w` e
`canvas.h`, em por-mil), e a espessura é a medida real do baralho. Os cinco vivem
na mesa, e os receptores (`carta_3d.gd`, `cursor_3d.gd`, `painel_carta_3d.gd`)
**não têm default** — cada um tem `assert` que reclama se a medida não chegar.

O motivo de não haver default: um default errado é uma armadilha silenciosa. Com
ele, o dia que alguém montasse uma carta fora da mesa sairia 10x mais grossa sem
nenhuma falha. É melhor a peça nascer do tamanho zero com grito.

**O raio e os segmentos existem porque a moldura deixou de ser um retângulo.** A
face da carta é geometria própria, montada no jogo, e ela tem de ter o **mesmo**
canto do corpo 3D: com o raio certo e menos segmentos, a moldura entra para
dentro da silhueta e aparece um fio de carta; com mais, ela passa para fora. Só
com os dois iguais os dois polígonos traçam a mesma linha. `carta_3d.gd` mede o
raio e os segmentos do `.glb` e recusa quando não batem — a D70 aplicada ao
canto, e é o que tira o canto desse de chute.

## 15.9 PRECEDÊNCIA

Se este doc e o código divergirem, **o código está certo e o doc está errado** até
prova em contrário: o schema e o teste mandam.

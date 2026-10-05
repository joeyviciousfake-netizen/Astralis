# 15 — VISUAL DA MESA DE DUELO

> O contrato visual da mesa: o que é medido, de onde vem cada imagem, e quem é o
> dono de cada número do desenho. **Escopo: só desenho.** Nenhuma regra de duelo
> muda aqui (R1). As decisões são D37, D38, D41, D70 e D75; o porquê de cada
> uma está no `DECISOES.md`.

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
| 6 molduras de carta | `assets/frames/` do pack do editor (via `--project`) |
| 9 orbes de atributo | `assets/attributes/` do pack do editor |
| estrela de nível | `assets/estrelas/` do pack do editor |
| verso da carta | `assets/backs/` do pack do editor |
| arte da carta | `artwork` do dado, arquivo dentro do pack |
| retrato do duelista | `portrait` do dado, arquivo dentro do pack; vazio → placeholder cinza |
| fundo do tabuleiro | gerado em código, sem imagem |

Sem arquivo no pack a carta usa o fallback: cor no lugar da moldura, sem orbe nem estrela, marrom com espiral no verso.

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
| `PAINEL_ESQ_L` | `431` px | o campo começa depois do painel 2D (22,4% da tela: 375 da carta + 2x28 de margem) |
| `JANELA_CAMPO_L` | `1489` px | 77,6% da tela — a janela do SubViewport |
| `ESCALA_CAMPO` | `1.185` | transform de apresentação, sobre o layout da arena (com ele as pilhas encostam nas bordas da janela) |
| `DESLOC_CAMPO` | `Vector2(0.0, -0.07)` | idem |

O centro do campo cai em **61,2%** da tela, e a simetria nas 4 fileiras é exata.

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
| área do campo (SubViewport) | x 22,4%..100%, altura toda |
| painel esquerdo | x 0..22,4% |
| retrato | 7,5% de largura, margem igual nos 3 lados |
| nome do duelista | alinhado ao topo da foto |

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

## 15.6 A FAIXA DO MEIO (removida)

A faixa do meio saiu da tela: o vão entre as fileiras mostra o fundo, o LP
mora embaixo do nome de cada duelista no topo, o baralho deita de costas e o
cemitério mostra a última carta aberta nos slots 3D do campo, e o turno não
tem visual.

## 15.7 ONDE O DESENHO MORA: OS 9 ARQUIVOS

| Arquivo | Assunto | O que ele decide |
|---|---|---|
| `astralis/duel3d/mesa_3d.gd` | a mesa: orquestrador | o estado do duelo, o boot, o redesenho, e é o **dono das medidas** |
| `astralis/duel3d/vista_3d.gd` | a vista e a volta | câmera, pivô e `giro_campo` (doc 16) |
| `astralis/duel3d/entrada_mao_3d.gd` | a entrada da carta comprada | de onde ela sai, o arco, o escalonamento e o **tempo** do voo (doc 16 §16.5) |
| `astralis/duel3d/campo_3d.gd` | o campo de vidro | onde os 24 painéis de vidro ficam (20 slots + 4 pilhas) |
| `astralis/duel3d/carta_3d.gd` | a fábrica de carta | corpo, arte, ATK e verso de uma carta 3D |
| `astralis/duel3d/cursor_3d.gd` | o cursor de foco | a moldura azul e a mão branca |
| `astralis/duel3d/painel_carta_3d.gd` | o painel esquerdo | a carta 3D da carta focada, ATK/DEF, nome, tipo e descrição |
| `astralis/duel3d/menus_3d.gd` | os menus 3D | o menu do LP e o da estrela |
| `astralis/duel3d/moeda_3d.gd` | a moeda do sorteio | o desenho do sorteio: onde ela nasce, como entra e qual face para (secao 15.10) |

**Três regras atravessam os nove (R9, D57):**

1. **Um arquivo = um assunto**, e o assunto manda na divisão — nunca a contagem,
   e nunca criar arquivo minúsculo só para existir.
2. **Número com um dono só.** Quem mede é a mesa; o assunto **recebe por parâmetro
   ou `Callable`** e nunca copia o número de outro. E o receptor **não tem
   default**: se a medida não chegar, ele nasce do tamanho zero e grita (D70).
   A entrada da mão é o exemplo: a mesa diz **de quem** e **quantas**, e quem
   responde pelo tempo do voo é o arquivo da entrada.
3. **A UI nunca guarda cópia do estado.** Ela pergunta ao dono na hora de
   desenhar. Guardar cópia faz a tela mostrar turno velho depois que o duelo muda.

**Estado atual:** os nove cumprem a regra, menos a `mesa_3d.gd`, cujo
orquestrador ainda carrega assunto demais. A divisão pelo assunto é o resto do
trabalho (ver as dívidas no `SESSAO_ATUAL.md`).

## 15.7.1 AS PILHAS (baralho e cemitério no campo)

Cada lado tem 2 painéis a mais, ao lado do campo e no meio entre as fileiras:
o `d0` (baralho, à direita) e o `g0` (cemitério, à esquerda). O vidro tem o
tamanho da carta EM ATAQUE (largura x altura + a folga, nunca quadrado),
porque carta de pilha nunca fica em defesa. O baralho deita de costas e o
cemitério mostra a última carta aberta em cima; pilha vazia é só o vidro. O
cursor não anda nas pilhas.

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

## 15.9 A CARTA DO PAINEL É A CARTA 3D (D75)

O painel esquerdo **não tem imagem 2D de carta**. A carta que ele mostra é a
**peça 3D de verdade** — a mesma que o campo e a mão desenham — montada pela
mesma fábrica (`carta_3d.gd`) com o mesmo dado: corpo do `.glb` com o canto
arredondado, moldura, arte na janela, orbe, fileira de estrelas, nome e ATK/DEF
impressos. Uma segunda carta, desenhada só para o painel, seria um duble do que
a mesa mostra, e um duble na tela é a classe de defeito que o R1 existe para
impedir.

**A janela.** A peça mora num `SubViewport` próprio dentro do painel, com
`own_world_3d` (não divide o mundo do campo, cuja câmera gira 180°) e fundo
transparente (o azul-marinho do painel aparece atrás). O GUT trava as três.

**O olho é outro, e ele é reto.** A janela tem uma `Camera3D` **ortogonal, de
frente**: o painel é lugar de informação, então a carta é lida sem perspectiva
nem distorção. Isso não muda a peça, muda o ponto de vista — e o olho do painel
**não é a câmera da mesa**. A trava de não deslocar a lente (D41) e a trava da
volta (D47) são da câmera do campo; o painel tem a sua, e ela é ortogonal por
decisão, não por acidente.

**O retângulo tem a proporção real da carta** (59 x 86), não a da moldura em
JPG: o que o painel desenha é a peça, e a peça mede 59 x 86. Com a altura da
faixa da referência (546 px, y 16..562) a largura sai 375 px, centrada nos 431
do painel (28 px de margem de cada lado, a mesma dos textos). A câmera ortogonal com `size` = altura da carta e `KEEP_HEIGHT` faz a
peça preencher o retângulo exato — nem sobra, nem corta o canto arredondado, e
o GUT mede isso em vez de deixar no olho.

**A medida vem da mesa.** O painel recebe `larg_carta`/`alt_carta` sem default,
com `assert`, como os outros receptores (D70).

**Na vez do rival** a janela mostra a carta **de costas**: dado vazio, peça
virada 180°, e o que aparece é o verso padronizado do jogo. Nenhum dado vaza.

**A peça só é remontada quando o id da carta muda** (`carta:<id>`, e
`verso:padrao` para o verso — o `:` não existe em id de carta, então as chaves
não se confundem). É o remember do que já foi desenhado, não cópia do estado do
duelo: o cursor anda a cada passo e remontar corpo, face, arte e quads 60x por
segundo é desperdício.

## 15.10 A MOEDA DO SORTEIO (D77)

A moeda do `turn_order: "moeda"` (doc 13) é um desenho **na frente da câmera**,
na tela de quem assiste. Ela **não vira a tela, não esconde nada e não tem pulo**.
A perspectiva do jogador, as cartas, o painel e o marcador ficam onde estavam a
coluna inteira — o que muda é que uma moeda aparece no ar em cima do marcador.

**A POSIÇÃO é no sistema da câmera**, e é por isso que a moeda não sai do lugar
quando a mesa gira: `moeda_3d.gd` é **irmã** do pivô (`PivoMesa`), não filha
dele. O pivô gira na entrega do turno, e uma moeda dentro dele viraria de perfil.

| Medida | Valor | Por quê |
|---|---|---|
| `DISTANCIA` | `9.5` | quão perto nasce (perto demais invade as cartas) |
| `FRACAO_DIAMETRO` | `0.15` | fração da **altura da tela** — não unidades de mundo |
| `ALTURA_FINAL` | `0.225` | fração acima do centro, medida no **vão** (abaixo) |
| `VOLTAS` | `8.0` | **par** de meias voltas (D77) |
| `MEIA_VOLTA` | `PI` | o que troca a face |

**O VÃO onde a moeda vive** é o espaço entre as fileiras, medido na tela. A
moeda tem que caber **inteira** nesse vão: ela é 3D e o campo a desenha
depois, então uma moeda mais alta some atrás das cartas do inimigo. O teste
trava a **invariante** (a moeda não invade nenhum dos dois lados), não o número.

O tamanho e a altura são **frações da tela**, e não unidades de mundo, porque a
câmera é de perspectiva (`CAM_FOV = 20°`, telefoto): o tamanho em unidades de
mundo depende do FOV e da distância, e quem escreve em fração não precisa ser
corrigido quando um dos dois muda. A altura do quadro é `2 · d · tan(fov/2)`.

**A PEÇA É `UNSHADED`, COMO O RESTO DA TELA.** O `.glb` traz o metal como PBR de
verdade (`roughness` 0.25 com clearcoat), e **PBR sem luz é preto**: a cena do
duelo não tem iluminação e não vai ter, então o material importado sairia escuro e
sem a cor do Blender. `_pintar_sem_luz` põe `SHADING_MODE_UNSHADED` em **todo**
material da peça, que é o mesmo modo das cartas e do vidro. A luz
que viaja com a moeda continua existindo, mas não para iluminar o metal: é o brilho
do **estouro** final.

**O GIRO é em torno do eixo vertical da tela** (a moeda tomba como quem rola uma
moeda na beira do dedo). Girar em torno da própria normal da face deixaria a face
sempre virada para a câmera e **o giro sumiria da tela**. `VOLTAS` é **par**
porque o rival começa meia volta adiante: com um total ímpar, os dois lados
terminariam na face errada.

**A RESPOSTA é a face, e não há nome escrito:** a **estrela** é o jogador e o
**losango** é o rival. Uma silhueta é lida em um quinto de segundo e um nome em
um segundo inteiro — escrever o nome seria traduzir a resposta que o jogador já
recebeu. Quem sabe qual face é qual é o `.glb`, não o `.gd`.

**A DISTRIBUIÇÃO INICIAL anima, e é a MESMA animação da compra** (D78). As 5
cartas de cada lado chegam uma por uma do baralho, no tempo normal do voo — não
existe tempo novo de distribuição, e o dono do tempo é `entrada_mao_3d.gd`. A
ordem no boot é **distribuição → moeda**: quem abre o duel vê a mão se encher
antes de saber de quem é a vez.

**A ESPERA É UMA COISA SÓ, E A MESA QUE DIZ QUE ELA EXISTE** (D80). Existe moeda na
tela quando o **dado** do duelo é `turn_order: "moeda"` (ou a flag de prova
`--mesa3d-moeda`) — a resposta sai de `_tem_sorteio_na_tela()` em `mesa_3d.gd`, e
é dela que nascem as duas travas:

- o **painel** em branco (`painel_carta_3d.gd` pergunta por `esperando_sorteio`):
  sem carta e **sem verso**, porque o verso do rival de costas também é resposta;
- a **navegação**: o `_unhandled_input` (teclado) e o `Input.is_action_pressed` do
  `_process` (analógico). O `set_input_as_handled` do primeiro não afeta o
   segundo, então os dois precisam da guarda;

A janela cobre a **distribuição inteira e a moeda**, e acaba com a resposta. Cobre
a distribuição porque é nela que o spoiler acontece: o motor já sabe quem começa
(D42) e a tela ainda não virou, então o cursor está no **lugar** da mão de quem
ganhou — irrespective de a moeda já estar na tela. Numa duel sem moeda não há o
que esconder: a espera não abre e o painel responde desde o primeiro quadro, como
sempre respondeu.

**Proibições:**

- **Não** girar a tela, colocar a câmera em 90° nem esconder mão/painel/cartas.
- **Não** pôr a moeda dentro do pivô (ela vira de perfil).
- **Não** escrever o nome de quem começa na moeda.
- **Não** dar pulo, tempo curto ou atalho no sorteio.
- **Não** girar em torno da normal da face (o giro não aparece).
- **Não** deixar `_girar` sobrescrever `_giro_extra` (aí os dois lados param
  na mesma face).
- **Não** deixar a moeda fora do vão (acima ela some atrás das cartas do
  inimigo; abaixo ela cobre o vão).
- **Não** usar material PBR na moeda (a cena não tem luz: sai preto).
- **Não** mostrar carta nem verso no painel enquanto a tela espera, nem deixar o
  cursor andar (o analógico precisa da guarda própria: `set_input_as_handled` não
  alcança `Input.is_action_pressed`).
- **Não** abrir a espera num duelo sem moeda, nem fazer o teste ligar a espera na
  mão para provocá-la.

---

## 15.11 PRECEDÊNCIA

Se este doc e o código divergirem, **o código está certo e o doc está errado** até
prova em contrário: o schema e o teste mandam.

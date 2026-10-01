# 17 — ASSETS 3D (Blender → jogo)

VERSION: 1.1 (2026-09-30, D62: a prévia oficial em Cycles na GPU, §17.10)
STATUS: AUTHORITATIVE para o pipeline de 3D
OWNER: lead (o contrato de convenções) + runtime (`core/asset_3d.gd`, o carregador)
DEPENDES: `02_PRINCIPIOS_ARQUITETURAIS.md` (R1/R3), `13_TABULEIRO_DUELO.md`,
`15_VISUAL_DUELO.md` (§15.2, a cascata de assets), D38, D49, D50, D61, D62

> **Escopo: SÓ DESENHO.** Um modelo 3D é elemento visual. Ele não decide
> regra nenhuma (R1) e não é lido pelo motor de duelo. Se algum dia um modelo
> precisar ser **dado** (um modelo por carta, por duelista), isso é campo novo
> no contrato + espelho no Studio — e não um detalhe de caminho de arquivo.

## 17.1 Por que o Blender entrou no projeto

A mesa é 3D e hoje tudo nela é **procedural** (caixas de vidro, céu, ladrilhos
montados no código). Isso é ótimo para o que é positioning e material, e ruim
para o que é forma: cidade de fundo, pilares, estátuas, peças de_details. Para
essas peças o Blender é a ferramenta certa — e a pergunta não é "dá para
gerar isso em código", é "qual das duas dá para o usuário mexer depois".

O preço de ter o Blender no meio é o de qualquer ferramenta externa: mais um
lugar onde a verdade pode se duplicar. Este documento existe para que o 3D
tenha **um** lugar por número, igual a arena (D50).

## 17.2 As três peças (e por que três, e não duas)

| Peça | Onde | Quem é o dono | Papel |
|---|---|---|---|
| **fonte do mesh** | `astralis/assets/3d/fonte/<id>.blend` | autor (pessoa/IA via MCP) | o `.blend` É a fonte. Só ele se edita no Blender |
| **artefato** | `astralis/assets/3d/<id>.glb` (+ `.import`) | jogo | o que o Godot carrega. Export determinístico do `.blend` |
| **números** | `astralis/assets/3d/manifest.json` | contrato | triângulos, vértices, caixa, materiais, convenções |

A pasta `fonte/` tem um `.gdignore`: sem ele o Godot trata `.blend` como cena
e tenta importar (aconteceu, e gerou um `estrela_teste.blend.import` órfão).
O `.gdignore` é versionado — sem ele um clone novo volta a importar o `.blend`.

**Regra dura (D50 applied):** triângulos, vértices, caixa e nome de material
de um asset vivem **só no manifesto**. Nem no código da mesa, nem em comentário.
E o manifesto é conferido por **dois medidores independentes do mesmo
artefato**: o exportador (Blender, medindo o `.glb` que acabou de gerar) e o
GUT (Godot, medindo o `.glb` que o jogo carregou). Se os dois discordarem, ou
um dos dois discordar do manifesto, a suíte/export falha.

## 17.3 Convenções (travadas; o manifesto as repete e o exportador as exige)

| Convenção | Valor | Por quê |
|---|---|---|
| Unidade | 1 unidade = **1 largura de carta** (`LARG_CARTA = 1.0` na mesa) | o mundo da mesa já é medido em larguras de carta |
| Eixo | **Y para cima** no jogo; a conversão vem do exportador glTF (`yup=true`) | não é conversão nossa para inventar bug |
| Origem | **duas formas, e o asset declara a sua** em `topologia.origem` (ver abaixo) | peça deitada e peça em pé se posicionam diferente |
| Material | um por asset, `mat_<id>` | e o que a tela procura ao trocar o material |
| Nó do `.glb` | **identidade** (sem matrix/translation/rotation/scale) | transform no nó é o `.glb` mentindo: alguém "consertaria" no código (foi o `APROXIMA_MAGIA_*` que o D49 apagou) |

### Origem: `deitada` ou `em_pe` (D62, medido na carta)

`y=0` no chão **só é certo para peça deitada**. Uma carta em pé é centrada em Y,
porque a mesa a posiciona por `alt/2` a partir do centro. As duas são legítimas; o
que não vale é misturar, nem fingir que a regra é uma só.

| `topologia.origem` | Caixa no jogo | Quem é assim |
|---|---|---|
| `deitada` | face no plano XZ, espessura em Y, **`y` começa em 0** | estrela, peça que pousa no campo |
| `em_pe` | altura no eixo Y, espessura no Z, **`y` é simétrico** (centro em 0) | carta, peça que a mesa levanta |

O GUT lê a declaração e cobra a forma certa — não presume que tudo é deitado.

**A pegadinha que fixou essa regra (medida, não deduzida):** o exportador glTF
converte Blender Z-up para glTF Y-up, e a conta é
`game_y = Blender_z`, `game_z = -Blender_y`, `game_x = Blender_x`.
Autorar a carta **deitada**, copiando a estrela, dá no jogo uma carta **deitada**
**e** com a base em `y = -0,7288` — foi o portão do exportador que acusou
(`caixa.y` e `caixa.z` trocados contra o manifesto). Do jeito certo, a caixa da
carta nova é **idêntica** ao `BoxMesh(larg, alt, gross)` que a mesa monta hoje, e a
integração passa a ser só trocar a malha, sem tocar em posição.

Vale a regra: **quem tem eixo trocado entre `.blend` e jogo tem que ser medido no
`.glb`, nunca suposto.** O portão existe para isso.

O exportador **recusa** um `.glb` com transform no nó: ele mede e falha, não
corrige. Corrigir no arquivo é esconder o defeito.

## 17.4 O caminho, ponta a ponta

```text
  MCP (opencode) ──socket 127.0.0.1:9876──▶ Blender 5.2.2 LTS
                                                │  .blend em assets/3d/fonte/
                                                ▼
                              tools/blender/exportar_assets.py  (headless)
                                                │  .glb + mede + compara c/ manifesto
                                                ▼
                              astralis/assets/3d/<id>.glb  (+ .import no git)
                                                │  load() pelo Godot
                                                ▼
                              astralis/core/asset_3d.gd  →  a tela
```

### Autorar / iterar (com o MCP)

```powershell
.\tools\blender\abrir_blender.ps1 -Blend astralis\assets\3d\fonte\estrela_teste.blend
```

Isso abre o Blender **com o socket do MCP já no ar**. Não há clique e não há
"start no painel": o add-on `mcp-for-blender` tem auto-start que **não dispara
no Blender 5.2.2** (medido em 2026-09-30 — `bpy.types.blendermcp_server` não
existe depois de abrir o Blender; `bpy.ops.blendermcp.start_server()` na mão
sobe na hora). Por isso o início é `tools/blender/iniciar_blender.py`, chamado
pelo launcher. A porta tem que ser a mesma dos dois lados: a do Blender (aqui)
e a do servidor MCP que o opencode lança.

### Exportar (determinístico, sem GUI, pode rodar em CI)

```powershell
$env:BLENDER = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
& $env:BLENDER --background --factory-startup `
    --python tools/blender/exportar_assets.py -- exportar   # exporta, mede, compara
& $env:BLENDER --background --factory-startup `
    --python tools/blender/exportar_assets.py -- medir      # so mede (autorar novo)
```

### Como nasce um asset novo

1. Desenhe no Blender (via MCP ou na mão) e salve o `.blend` em
   `astralis/assets/3d/fonte/<id>.blend`, com a origem na base e o objeto
   chamado `<id>`.
2. Rode o exportador em `medir` e copie os números para o manifesto
   (`malhas`, `vertices`, `triangulos`, `caixa`, `materiais`).
3. Rode em `exportar`: ele confere. Divergiu, ele diz qual campo.
4. `Godot --headless --path astralis --import` (o `.import` do `.glb` é
   versionado, como os outros assets).
5. GUT: `test_assets_3d.gd` — mede do lado do Godot.

## 17.5 O que cada lugar é dono de saber

| Número | Blender (`.blend`) | Manifesto | `.glb` | `core/asset_3d.gd` |
|---|---|---|---|---|
| triângulos/vértices da fonte | sim (topologia) | — | (vira outro número, glTF quebra vértice) | — |
| triângulos/vértices que o jogo vê | — | **sim** | **sim** | lê do `.glb` |
| caixa no espaço do jogo | só convertendo | **sim** | **sim** | compara |
| material | sim | **sim** | **sim** | — |
| onde o objeto fica na tela | nunca | nunca | nunca | nunca (é a mesa) |

O `.glb` tem 60 vértices onde o `.blend` tem 20: o glTF quebra os vértices por
canto (normais/UV por face). Não é bug — é por isso que o manifesto guarda o
número **do artefato**, que é o que o jogo carrega.

## 17.6 Tamanho real (medido nesta máquina, 2026-09-30)

Cena de referência (1 pilar com Bevel+Array, 12 prédios, 20 peças de vidro =
34 objetos, 768 tris):

| | `.blend` comprimido | `.blend` cru | `.glb` |
|---|---|---|---|
| só malha | **94 KB** | 641 KB | **46 KB** |
| + 1 textura 1024² | 1,8 MB | 1,8 MB | 1,8 MB |

Conclusão: **malha é inexpensive; textura é o que pesa.** O estilo da mesa
(céu azul, vidro, metal) é material e cor pura, ou seja, quase zero KB. Por
isso o `.blend` é versionado sem medo, com a regra: *textura embutida só quando
for indispensável*.

O asset de teste (`estrela_teste`): 36 tris, 60 verts, 1 malha, `mat_estrela_teste`,
caixa `x[-0.4755, 0.4755] y[0, 0.15] z[-0.5, 0.4045]`, `.blend` 92 KB, `.glb` 3 KB.

## 17.7 DONO: do jogo, como a arena (D61)

Assets 3D são do **jogo**. Um projeto de usuário **não** sobrescreve mesh de
mesa. Isso é escolha, não acidente: é a mesma razão do D50 (o override por
projeto da arena caiu porque fazia o jogo cair numa tela diferente em
silêncio). Se um dia o usuário quiser malha própria, é campo novo no contrato
+ espelho no Studio — decisão do usuário, com o caminho escrito.

O `card_layout` (doc 04.8) continua sendo o molde **2D** da carta; o 3D não
entra nele. Uma carta pode, no futuro, ter um modelo 3D — e aí será `card`
ganhando campo novo, com schema, espelho no `main.rs` e `fm_import --check`.

## 17.8 O que NÃO é

- Não é contrato: mudar convenção de 3D **não** é `contract_files` (isso é o
  JSON entre Studio e jogo). É convenção de desenho, mora aqui.
- Não é motor: `core/asset_3d.gd` não decide lugar, escala, nem nada de regra.
- Não é efeito, animação ou física: o `.glb` entra estático; `animation/import`
  fica desligado no import.
- Não é lugar de mexer no asset: se o `.glb` está errado, corrige-se o `.blend`
  e re-exporta — **nunca** o `.glb` na mão e **nunca** um número no jogo.

## 17.9 A MALHA TEM QUE ENTRAR SANA (a regra do autor)

**Face de 4 lados, nunca face de mais de 4 lados.** Triângulo é aceito (e às
vezes é o único caminho); n-gon não.

**Por que o n-gon é proibido — e a medida, não o gosto.** Num contorno
côncavo as diagonais de uma face de N lados **não estão em lugar nenhum**: o
exportador escolhe na hora de triangular (foi o que apareceu na estrela de
teste: uma tampa de 10 lados virou "5 orelhas + 3 triângulos" do pentágono
interno). A área fecha e o render sai certo, então **nenhuma medida de área,
caixa ou triângulo acusa o problema** — mas a mesma `.blend` entregue a outra
ferramenta (o import do Godot, um otimizador, outro exportador) escolhe
diagonais diferentes, e numa forma côncava a diagonal muda o resultado. O
defeito é **irreprodutibilidade**, e ele é invisível justamente porque a
geometria está certa.

> **O `.glb` tem triângulos e sempre vai ter** — o glTF só tem triângulos, é
> formato, não escolha. O que não pode mudar é a **fonte**: no `.blend` a
> topologia é de quads, e é ela que sobrevive.

### A construção de referência (a estrela de teste)

As 2 tampas são **5 quads cada, girando em torno de um vértice central**. Cada
quad cobre duas pontas e o vale entre elas: `(C, v_i, v_i+1, v_i+2)`, com `i`
par. A conta fecha, e fecha antes de construir:

```text
5 quads x 2 setores = os 10 setores da estrela inteira
V=11  E=15  F=5   ->   V-E+F = 1   (disco valido)
soma dos cantos de face = 10 + 5 + 5 = 20 = 4 x 5
```

Com as 10 paredes (já quads), o sólido fecha: `V=22 E=40 F=20`, `V-E+F=2`
(casco), **40 arestas em exatamente 2 faces**, volume por divergência positivo
(normais todas para fora) e a **caixa idêntica** — a silhueta não se mexeu.

> **Onde o quad puro é impossível, a conta diz.** Uma estrela de 5 pontas com
> as 10 pontas de valência 1 e só quads exigiria `4F ≡ 2 (mod 4)`, que não tem
> solução inteira. Se uma peça precisar de quads onde a conta não fecha, o
> caminho é **inserir vértices** (loop cut nas arestas) e emendar os anéis — não
>(forçar) um n-gon e deixar a diagonal por conta da exportação.

### O portão: onde isso é verificado (e por que na FONTE)

`tools/blender/exportar_assets.py` audita a malha e **recusa** (§17.3: mede e
falha, não corrige). **A auditoria da topologia roda na `.blend`, com bmesh** —
porque no `.glb` o n-gon **já virou triângulo** e o defeito some de vista. É o
único lugar onde ele existe.

| Check | Onde | Ação |
|---|---|---|
| face com mais de 4 lados | fonte (bmesh) | **erro** |
| face degenerada (área 0) / repetida | fonte | **erro** |
| vértice solto (nenhuma face usa) | fonte | **erro** |
| aresta de bordo / aresta com >2 faces | fonte | **erro** (aberta / não-manifold) |
| normal gravada ≠ normal geométrica | artefato | **erro** — é o "alguns polígonos parecem errados" |
| área total da fonte ≠ área do artefato | as duas | **erro** — a triangulação perdeu ou vazou geometria |
| nenhuma face de 4 lados | fonte | **aviso** — nem toda peça precisa de quad |

O portão é **provado nos dois sentidos**: ele pega n-gon, face degenerada,
malha aberta e vértice solto (sonda descartável, 4 de 4), e passa na estrela
de verdade com 0 problemas.

A saúde da malha **viaja no manifesto** (`topologia` de cada asset: `faces`,
`quads`, `tris_fonte`, `ngons`, `fechada`), e o GUT (`test_assets_3d.gd`)
confere — é o terceiro medidor, e **sem escrever nenhum número à mão**: foi
repetir os "36 triângulos" dentro do teste que o fez divergir do manifesto
sozinho quando a estrela mudou. Se precisar repetir um número, ele está no
dado errado.

## 17.10 A prévia oficial: Cycles na GPU (D62)

O renderizador do projeto é **Cycles** (decisão do usuário, D62), e a prévia de
um asset é `tools/blender/preview.py`.

O que ela trava, e por quê:

| Trava | Motivo |
|---|---|
| **Cycles, e só Cycles** | decisão do usuário; e o render está gravado no próprio `.blend` fonte (`engine=CYCLES`, `device=GPU`), então quem abre a fonte vê o mesmo render que a prova |
| **GPU obrigatória** (sem GPU o script falha; `--cpu` só a pedido) | render "de GPU" que cai na CPU em silêncio não prova nada — é a mesma família do defeito do D50 |
| **CPU desligada do Cycles** | o backend éOptiX (medido: Blender 5.2.2 LTS vê a RTX 5060 em OPTIX e em CUDA); o dispositivo CPU fica com `use = false` para o render não escorregar para ele |
| **Amostras e semente fixas** (256, semente 0, denoise, AgX) | a prévia não pode mudar cada vez que é refeita |
| **Cenário montado pelo script** (3 luzes + fundo na cor da mesa, sem HDRI e sem arquivo externo) | a prova não depende de nada além do script, e duas prévias de assets diferentes saem comparáveis |
| **Enquadramento 3/4 calculado da caixa** com folga fixa | uma regra só para todo asset; a prova mostra o asset inteiro, sempre do mesmo ângulo |

**O que a prévia NÃO garante (medido, não prometido):** o Cycles na GPU **não
é bit-exato** entre execuções — a soma em float do kernel não é associativa e a
ordem das operações muda com o escalonamento. Duas execuções da mesma cena
deram PNGs de 465.048 e 465.113 bytes, com sha256 diferente. Por isso a prévia
**mede** em vez de prometer: `--comparar <outro.png>` faz o A/B pixel a pixel
(o mesmo método das fotos da mesa, doc 16 §16.12). Resultado medido na estrela:
**0 de 589.824 pixels com diferença maior que 1 passo de 8 bits (0,0000%)**,
delta máximo 0,0039 (= 1/255), delta médio 0,000000. A imagem é a mesma; o que
muda é o byte do PNG.

**O que continua sendo a garantia é a geometria, não a imagem:** o `.glb`
medido contra o manifesto, pelos dois medidores (§17.2). E o renderizador não
entra no `.glb` (o export glTF não depende do render): depois de gravar CYCLES
na fonte, o exportador reexportou, o manifesto continuou batendo e o `.glb`
saiu byte a byte igual.

Custo medido: 768×768 com 256 amostras leva **3 a 5 s** na RTX 5060.

> **O jogo não tem Cycles.** Isso aqui é o render do *Blender*, ou seja, das
> provas de asset. O render do jogo continua sendo o do Godot (Forward+/Mobile) —
> e nenhum dos dois toca no outro: o `.glb` é geometria, sem luz.

## 17.11 Decisões do usuário (abertas, sem pressa)

1. **Primeiro asset real** da mesa. A lacuna listada no doc 15 §15.5 é a
   cidade de fundo; os pilares de vidro são a opção mais barata (a mesa já
   tem a "_vidro" duplicado em código). **A topologia de referência a seguir é a
   estrela de teste (§17.9)** — 5 quads por tampa em torno de um vértice
   central —, e o portão já recusa qualquer peça que não passe nela.
2. **Se o projeto do usuário pode ter 3D próprio** (hoje: não, D61).
3. **Parâmetros de import por asset**: o `.import` do `.glb` hoje usa o padrão
   do Godot (`generate_lods`/`create_shadow_meshes` ligados, inúteis para
   peça pequena). Ajuste por asset é possível e é dado do `.import` versionado.
4. **Peça que precise de n-gon de verdade** (uma tampa cilíndrica, um disco):
   hoje o portão recusa. A saída, se um dia precisar, é um campo novo no
   manifesto dizendo qual face pode ser n-gon — **não** afrouxar o portão.

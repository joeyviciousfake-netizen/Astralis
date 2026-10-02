# 17 — BLENDER

> Guia de trabalho do Blender: como abrir com o MCP e o que fazer em cada passo
> de um modelo. **Cresce a cada modelo** — o que se aprende aqui entra aqui,
> direto e sem história.
>
> Dono: Runtime (o `.blend` é do asset que o runtime usa). Ferramentas em
> `tools/blender/`. A regra que manda em tudo aqui é a **R12**, e o primeiro
> passo dela é **consultar a documentação** — este documento e o manual do
> Blender em `blender_manual_v520_en.html/` (§17.7) — antes de fazer algo que
> não se sabe ou não se tem certeza.

## 17.1 ABRIR O BLENDER COM O MCP

**Um comando, da raiz do repo:**

```powershell
.\tools\blender\abrir_blender.ps1
```

Com um arquivo: `.\tools\blender\abrir_blender.ps1 -Blend caminho.blend`
Em outra porta: `$env:ASTRALIS_MCP_PORT = 9881; .\tools\blender\abrir_blender.ps1`

**O launcher é o caminho, e não um atalho.** O auto-start do add-on `blender_mcp`
não dispara nesta versão do Blender, então quem sobe o servidor é o
`tools/blender/iniciar_blender.py`, e ele só roda pelo launcher.

O launcher, em ordem:

1. acha o Blender — `$env:BLENDER` primeiro, depois a **versão LTS mais alta** em
   `C:\Program Files\Blender Foundation` (5.2 vence 5.1);
2. passa `ASTRALIS_MCP_PORT` (padrão **9876**) e o caminho do `ASTRALIS_STATUS`;
3. abre o Blender **na frente da pessoa**, com `--python` no `iniciar_blender.py`;
4. espera a porta aparecer e imprime o estado: o backend do Cycles e se o MCP
   subiu. Sem essa linha, o MCP está fora.

O `iniciar_blender.py` habilita o add-on (idempotente), abre o `.blend` se
houver, **força o Cycles na GPU** e sobe o socket.

**A porta tem que ser a mesma dos dois lados:** a do Blender (o launcher) e a do
servidor MCP do cliente (`~/.config/opencode/opencode.json`, chave `blender`).

**A ordem importa.** O servidor MCP procura o Blender **quando sobe**. Com o
Blender ainda fechado, o servidor fica sem destino e **toda chamada dá
timeout**. A ordem é: Blender no ar com o socket escutando, e só então o
servidor MCP.

Conferir o socket, quando precisar saber se o Blender está de pé:

```powershell
Get-NetTCPConnection -LocalPort 9876 -State Listen
```

Uma linha `Listen` com o `OwningProcess` do Blender é o que tem que aparecer.

## 17.2 QUANDO O MCP DÁ TIMEOUT

O timeout **não diz onde está o defeito**. São três lugares possíveis, e nesta
ordem:

| Checar | Como | Se der o que |
|---|---|---|
| O Blender está escutando? | `Get-NetTCPConnection -LocalPort 9876 -State Listen` | nada → o launcher não rodou; abra o Blender |
| O Blender responde? | socket direto, JSON na 9876 (abaixo) | responde → o Blender está bom e o defeito é do servidor MCP |
| O servidor MCP está no ar? | `Get-Process uvx` | não está → suba o `uvx` da config, ou reinicie o cliente |

**Falando direto com o Blender, sem passar pelo MCP.** O protocolo é um JSON por
soquete TCP, e serve para separar "o Blender quebrou" de "o cliente quebrou":

```python
import socket, json
s = socket.create_connection(("127.0.0.1", 9876), timeout=8)
s.sendall(json.dumps({"type": "get_scene_info"}).encode())
print(json.loads(s.recv(65536).decode())["status"])
```

A resposta vem `{"status": "success", "result": {...}}`. Se isso responder, o
Blender está perfeito e o problema é da ponte MCP — aí o conserto é reiniciar o
opencode, porque o cliente **não relança o servidor MCP sozinho**.

**Versão do add-on.** O servidor MCP confere o protocolo do add-on instalado ao
subir. Add-on velho com servidor novo (ou o contrário) dá falha de protocolo: a
conferência é `uvx mcp-for-blender install-addon`, e depois **reiniciar o
Blender** (o add-on só é lido no boot).

## 17.3 ESCALA REAL: UNIDADE E PLANO DE CORTE

Modelo em medida de verdade é o certo, e tem duas armadilhas que fazem o
objeto **não aparecer** — e nenhuma das duas é erro do modelo.

**A unidade.** `1 unidade = 1 metro`, e a interface em milímetros, para a tela
mostrar `59 mm` e não `0.059`:

```python
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
scene.unit_settings.length_unit = 'MILLIMETERS'
```

O `length_unit` é um **enum dinâmico**: a API só devolve `DEFAULT` antes de o
sistema estar definido, então **pergunte ao Blender** em vez de chutar o
identificador (tente os valores e veja qual ele aceita).

**O plano de corte.** O clip de perto da tela 3D vem em `0,1 m` (100 mm). Um
objeto de 59 mm fica **inteiro atrás dele** e simplesmente não aparece. Abaixo do
tamanho do menor objeto da cena:

```python
for screen in bpy.data.screens:
    for area in screen.areas:
        for space in area.spaces:
            if space.type == 'VIEW_3D':
                space.clip_start = 0.0002   # 0,2 mm
                space.clip_end = 100.0
```

## 17.4 A CARTA DE DUELO

A carta de Yu-Gi-Oh mede **59 × 86 mm** com **0,30 mm** de espessura. A
espessura é a do baralho de verdade: no jogo ela é uma divisão (`0,30 / 59`), e
arredondá-la faz a carta nascer 10x mais grossa em silêncio.

| Eixo | Medida | Papel |
|---|---|---|
| X | 59 mm | largura |
| Y | 0,30 mm | espessura (a carta fica de pé, virada para −Y) |
| Z | 86 mm | altura |

Base apoiada em **Z = 0**, então a posição do objeto é `z = altura / 2`. A escala
do objeto fica **1,1,1**: a medida mora na malha, nunca na escala, senão a
espessura vira 10x no `.glb`.

**O corpo**, com a escala aplicada (senão a escala fica pendurada):

```python
bpy.ops.mesh.primitive_cube_add(size=1.0)
carta = bpy.context.active_object
carta.scale = (0.059, 0.0003, 0.086)
bpy.ops.object.transform_apply(scale=True)   # <- sem isto a espessura viaja errada
carta.location = (0.0, 0.0, 0.043)
```

**As pontas arredondadas.** As "pontas laterais" são os 4 cantos da silhueta, e
elas são as 4 arestas que correm **ao longo da espessura (Y)**. Um vértice conta
como ponta quando o X e o Z batem entre os dois vértices da aresta. Marcar só
essas, e o Bevel em modo `WEIGHT`:

```python
attr = me.attributes.get("bevel_weight_edge") or \
       me.attributes.new("bevel_weight_edge", 'FLOAT', 'EDGE')
for e in me.edges:
    a, b = me.vertices[e.vertices[0]].co, me.vertices[e.vertices[1]].co
    ponta = abs(a.x - b.x) < 1e-9 and abs(a.z - b.z) < 1e-9 and abs(a.y - b.y) > 1e-9
    attr.data[e.index].value = 1.0 if ponta else 0.0

bev = carta.modifiers.new("Pontas", 'BEVEL')
bev.limit_method = 'WEIGHT'      # respeita a marcação: só as 4 pontas
bev.offset_type = 'OFFSET'      # em OFFSET, o valor é o próprio raio
bev.width = 0.002                # 2 mm
bev.segments = 8
bev.miter_outer = 'MITER_ARC'
bev.use_clamp_overlap = True
```

O Bevel **já entrega a topologia** — não é preciso modelar o arco à mão. Marcar
as arestas por `bevel_weight_edge` e deixar o modificador gerar é o caminho
curto; modelar o arco vértice a vértice seria refazer na mão o que o programa
faz melhor.

Depois de aplicar o modificador, **apague o atributo `bevel_weight_edge`**: ele
só existia para o Bevel achar as arestas, e um atributo morto não deve ir para o
`.glb`.

**As tampas saem n-gon do Bevel, e é aí que a carta tem que ser consertada.** O
Bevel troca cada canto por um arco e a face grande que ficava ao lado vira uma
única face de `4 × (segmentos + 1)` lados. Com 8 segmentos são **duas faces de 36
lados**. A correção é triangular **só essas duas**, nunca a malha toda, senão os
quads da parede viram triângulos e o custo sobe:

```python
bm = bmesh.new(); bm.from_mesh(me)
ngons = [f for f in bm.faces if len(f.verts) > 4]
if ngons:
    bmesh.ops.triangulate(bm, faces=ngons,
                          quad_method='BEAUTY', ngon_method='BEAUTY')
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(me); bm.free()
```

O `8` de `segments` não é gosto, é a conta de §17.5: cada segmento a mais custa
16 triângulos na carta inteira.

**O sombreamento.** As faces planas (frente, verso, laterais) têm de continuar
planas e só o arco ficar redondo:

```python
bpy.ops.object.shade_auto_smooth(angle=0.5235988)   # 30 graus
```

`shade_smooth` liso deixaria a carta inteira com cara de borracha, que não é o
que um cartão laminado faz.

**O material não leva imagem.** A arte, a moldura e o verso entram no jogo,
vindos do dado (`astralis/duel3d/carta_3d.gd` monta a carta com `BoxMesh` + dois
`QuadMesh` texturizados). No Blender fica só o papel laminado, para a luz
mostrar o arco em vez de um retângulo chapado:

```python
bsdf.inputs['Base Color'].default_value = (0.90, 0.885, 0.85, 1.0)
bsdf.inputs['Roughness'].default_value = 0.38
bsdf.inputs['Coat Weight'].default_value = 0.55      # o verniz da carta
bsdf.inputs['Coat Roughness'].default_value = 0.06
```

Procura o nó pelo **`type`**, nunca pelo nome: em interface fora do inglês o nome
vem traduzido e a busca por nome volta vazio.

```python
bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
```

## 17.5 A MALHA ENTRA SANA: TRI OU QUAD, NUNCA NGON (R16)

Toda face da malha que vai para o jogo tem **3 ou 4 lados**. Triângulo e quad são
válidos; **n-gon é proibido**.

**Por que o n-gon é proibido — e a medida, não o gosto.** Num contorno côncavo as
diagonais de uma face de N lados **não estão em lugar nenhum**: quem exporta escolhe
na hora de triangular, então a mesma fonte entregue a ferramentas diferentes (o
import do Godot, um otimizador, outro exportador) produz geometrias diferentes. A
área fecha e o render sai certo, então **nenhuma medida de área, caixa ou
triângulo acusa o problema** — o defeito é **irreprodutibilidade**, e ela é
invisível justamente porque a geometria está certa.

**Onde o n-gon nasce.** Não é erro de modelagem, é o modificador entregando: o
Bevel troca o canto por um arco e a face grande ao lado vira uma face só, de
`4 x (segmentos + 1)` lados. Onde houver Bevel, Solidify ou qualquer coisa que
engorde o contorno, **a face grande é a suspeita**. Corrija triangular só ela.

**A conta do custo — e por que ela não tem escapatória.** Numa peça arredondada,
o total de triângulos do artefato sai da topologia, não do gosto:

```
triangulos = 16 x segmentos + 12
```

A parede lateral precisa de um quad por segmento de arco (`4N + 4`), e cada tampa é
um polígono de `4N + 4` lados, que leva `4N + 2` triângulos para não ser n-gon.
Um polígono de K lados **sempre** leva K-2 triângulos, e a parede **sempre** leva um
quad por segmento. Então o segmento do arco é o **único botão**, e ele se escolhe
sabendo o que cada um custa:

| Segmentos | Erro maximo do arco | % do raio | Triangulos |
|---|---|---|---|
| 2 | 0,152 mm | 7,6% | 44 |
| 4 | 0,038 mm | 1,9% | 76 |
| 6 | 0,017 mm | 0,86% | 108 |
| 8 | 0,010 mm | 0,48% | 140 |
| 12 | 0,004 mm | 0,21% | 204 |

O erro do arco e a distancia entre a corda e a circunferencia de verdade, num canto
de 90 graus: `raio x (1 - cos(90 / 2 x segmentos))`. **Nao justifique pelo pixel** —
a carta na tela e um argumento de tela, e a regra e da malha. O numero que vale e o
erro em % do raio, porque e isso que o formato mantem.

**O portao: a malha e medida antes de sair.** Um portao que recusa malha serve
para provar a regra, nao para ser o metodo (a acao e o modelar direito). O que
falha e so a entrega:

```python
def medir_malha(ob):
    import bmesh
    from collections import Counter
    bm = bmesh.new(); bm.from_mesh(ob.data)
    lados = Counter(len(f.verts) for f in bm.faces)
    arestas = {}
    for f in bm.faces:
        for e in f.edges:
            arestas[e] = arestas.get(e, 0) + 1
    ngons = {n: q for n, q in lados.items() if n > 4}
    fechada = set(arestas.values()) == {2}      # toda aresta em 2 faces
    tri = sum(max(0, len(f.verts) - 2) for f in bm.faces)
    bm.free()
    return {"faces": len(ob.data.polygons), "quads": lados.get(4, 0),
            "tris": lados.get(3, 0), "ngons": ngons, "fechada": fechada,
            "triangulos": tri}
```

O que o portao recusa: **n-gon** (erro), **malha aberta ou nao-manifold** (erro —
`fechada` falso), **face degenerada de area 0** (erro). O que ele nao recusa:
triangulo. Triangulo e uma face legitima e, numa tampa plana, ele e **mais barato**
que o quad: um polígono de K lados leva K-2 triangulos, enquanto o mesmo
contorno em quads leva K/2 quads — que sao K triangulos. Para a mesma silhueta,
**triangular e mais barato que quad**.

**Grid Fill nao serve para a tampa arredondada.** O manual diz que ele preenche um
loop "roughly rectangular", e o contorno de uma peca arredondada nao e: sao 4
lados longos de 1 aresta e 4 arcos de N arestas. Ele recusa e devolve a malha sem
preencher, e o escopo fica aberto. Nao gaste tempo com ele aqui: **triangular a
face grande e mais barato e mais honesto**.

## 17.6 MEDIR ANTES DE CONCLUIR

O número que vale é o **medido na malha**, não o digitado no script. Duas
medidas que evitam erro:

**O raio da ponta.** Numa ponta de raio `r`, o arco vai de `(x_max, z_max - r)`
até `(x_max - r, z_max)`. Meça por **um canto por vez**, em coordenada local do
canto — senão a ponta de baixo entra na conta e o raio sai absurdo:

```python
def raio(sx, sz):                       # sx, sz = +1/-1: qual canto
    canto = [(c[0]*sx, c[2]*sz) for c in vs if c[0]*sx > 0 and c[2]*sz > 0]
    r1 = z_max - min(w for u, w in canto if abs(u - x_max) < 1e-6)
    r2 = x_max - min(u for u, w in canto if abs(w - z_max) < 1e-6)
    return r1, r2                          # os dois têm de concordar
```

**`validate()` devolve o contrário do que o nome sugere.** nesta versão ele
devolve **`True` quando corrigiu algo** e **`False` quando a malha já está
sadia**. Descubra o que ele quer dizer num caso controlado, não no modelo real:

```python
tmp = bpy.data.meshes.new("T")
tmp.from_pydata([(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                 (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)], [], [...])
tmp.validate(verbose=False)               # cubo novo, sem defeito
```

Um cubo novo que devolva `True` é o sinal de que o `True` **é** o defeito — e
aí vale investigar o modelo.

**Clamp Overlap é rede, não método.** Ele limita a largura para a aresta não se
sobrepor. Ligado por precaução, e **medido** para saber se ele apertou: se o raio
medido bate com o raio pedido, o clamp não mexeu em nada.

## 17.7 A DOCUMENTAÇÃO (primeiro passo da R12)

O manual do Blender está **na máquina**, em `blender_manual_v520_en.html/`. A
raiz é `index.html`; o `LEIA-ME-ASTRALIS.md` de dentro explica a origem. Ele
**não está no git** (1,3 GB, 5.547 arquivos, material de terceiro), e a R12
existe justamente para ele ser consultado sem depender de internet.

**Como achar a página.** A árvore do manual é enorme e o menu se repete em
toda página, então o caminho é **mais rápido que a busca**: vá direto pelo
caminho do arquivo sob a pasta. O que o Bevel usa, por exemplo, é

```text
blender_manual_v520_en.html/modeling/modifiers/generate/bevel.html
```

Quando a página é grande demais para ler inteira, **grepe o termo** em vez de
carregar tudo — o menu é o mesmo HTML repetido, então `Select-String` pelo
assunto resolve.

O que o manual do Bevel confirma, e que muda o resultado:

- **Limit Method / Weight** — usa o atributo, e peso `0.0` não arredonda nada.
  É o que permite arredondar só as 4 pontas sem tocar no resto da carta.
- **Width Type / Offset** — a distância da aresta nova até a original. Num
  canto de 90 graus isso **é o raio**, que é o que a carta usa.
- **Loop Slide** (ligado por padrão) — quando uma aresta arredondada encontra
  uma que não foi, o bevel escorrega pela vizinha; desligar dá largura mais
  uniforme.
- **Miter Shape** não tem efeito com menos de 2 segmentos.

Na internet, o mesmo manual fica em
<https://docs.blender.org/manual/en/latest/> — mas a cópia local é a que não
depende de conexão.

## 17.8 O QUE REGISTRAR AQUI

Toda vez que um modelo ensina algo — uma armadilha de escala, um enum que não é
o que o nome diz, um limite que só aparece em medida real —, o certo é **entrar
neste documento** como regra, com o motivo, e não como memória do que deu errado.
O histórico é o `git log`; aqui é o que vale.

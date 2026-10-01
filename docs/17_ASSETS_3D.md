# 17 — ASSETS 3D (Blender → jogo)

VERSION: 1.0 (2026-09-30)
STATUS: AUTHORITATIVE para o pipeline de 3D
OWNER: lead (o contrato de convenções) + runtime (`core/asset_3d.gd`, o carregador)
DEPENDES: `02_PRINCIPIOS_ARQUITETURAIS.md` (R1/R3), `13_TABULEIRO_DUELO.md`,
`15_VISUAL_DUELO.md` (§15.2, a cascata de assets), D38, D49, D50, D59

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
| Origem | **base e centro**: `y=0` no chão, `x/z` centrados | o objeto pousa no plano do campo sem nenhum ajuste |
| Material | um por asset, `mat_<id>` | e o que a tela procura ao trocar o material |
| Nó do `.glb` | **identidade** (sem matrix/translation/rotation/scale) | transform no nó é o `.glb` mentindo: alguém "consertaria" no código (foi o `APROXIMA_MAGIA_*` que o D49 apagou) |

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

## 17.7 DONO: do jogo, como a arena (D59)

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

## 17.9 Decisões do usuário (abertas, sem pressa)

1. **Primeiro asset real** da mesa. A lacuna listada no doc 15 §15.5 é a
   cidade de fundo; os pilares de vidro são a opção mais barata (a mesa já
   tem a "_vidro" duplicado em código).
2. **Se o projeto do usuário pode ter 3D próprio** (hoje: não, D59).
3. **Parâmetros de import por asset**: o `.import` do `.glb` hoje usa o padrão
   do Godot (`generate_lods`/`create_shadow_meshes` ligados, inúteis para
   peça pequena). Ajuste por asset é possível e é dado do `.import` versionado.

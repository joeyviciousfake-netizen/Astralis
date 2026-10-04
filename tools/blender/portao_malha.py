"""portao_malha.py — o dono da malha que vai para o jogo: mede, recusa e confere.

Este arquivo e o UNICO portao da R16. Ele foi extraido de `exportar_carta.py`
porque a regra da R16 e uma so ("tri ou quad, nunca n-gon") e dois portoes
divergem: o segundo aceita a malha que o primeiro reprovaria, e a trava vira
decoracao. Cada publicador (`exportar_carta.py`, `exportar_moeda.py`) mede a
FONTE, normaliza uma COPIA e confere o artefato lendo o proprio `.glb`.

O QUE O PORTAO RECUSA, e por que cada recusa e um erro de verdade:

- **n-gon.** Em contorno concavo as diagonais de uma face de N lados nao estao
  em lugar nenhum: quem exporta escolhe na hora. A area fecha e o render sai
  certo, entao nenhuma medida de area, caixa ou triangulo acusa o problema — o
  defeito e IRREPRODUTIBILIDADE, e ela e invisivel justamente porque a
  geometria esta certa.
- **Malha aberta ou nao-manifold** (toda aresta tem de estar em 2 faces). E o
  que faz a peca ter furo, e furo na tela nao tem conserto.
- **Face degenerada (area 0).** Nao aparece em lado nenhum, so no vao.

O QUE O PORTAO **NAO** RECUSA: triangulo. Triangulo e face legitima e, numa
tampa plana, e MAIS BARATO que o quad — um poligono de K lados leva K-2
triangulos, enquanto o mesmo contorno em quads leva K/2 quads, que sao K
triangulos. Para a mesma silhueta, triangular e mais barato.

E O QUE SOBREVIVE AO ARTEFATO: o glTF quebra o vertice por canto (normais e UV
por face), entao as 2 faces que dividem uma aresta deixam de compartilhar indice
e a malha FECHADA nao da para ser conferida no `.glb`. Por isso o portao de
face roda na FONTE, e o artefato so e conferido no que sobrevive a quebra: o
triangulo, o vertice, a centragem, a largura e a identidade dos nos.
"""

import json
import struct
from collections import Counter

import bmesh
import bpy
from mathutils import Vector

# O jogo trabalha na unidade em que a LARGURA da peca e 1,0. A fonte esta em
# milimetro real (1 unidade do Blender = 1 metro), entao sem normalizar o
# artefato chega pequeno em silencio. E so o ALVO da normalizacao: a medida e da
# mesa (D70), e quem carrega o `.glb` reclama com `assert` se nao bater, entao
# aqui nao ha copia do numero da mesa.
LARGURA_JOGO = 1.0


def malha_medida(ob):
    """A malha que o jogo vai ver, e nao a que esta no arquivo.

    `ob.data` de um objeto com modificador NAO e a peca: e o que o modificador
    consome. A moeda e exatamente esse caso — o `ob.data` e so o perfil de 24
    arestas do torno (o Screw), e a peca de verdade so existe depois que o
    modificador roda. Medir `ob.data` ali da 0 faces, 0 triangulos e "malha
    aberta com 0 arestas fora de 2 faces", que e uma porta aberta sem nome.

    Por isso: com modificador, mede a malha AVALIADA (o mesmo caminho do
    publicador, com `export_apply`). Sem modificador, `ob.data` e a peca.

    Devolve `(malha, origem, avaliado)`: quem chama precisa do `avaliado` para
    liberar a malha temporaria com `to_mesh_clear()`.
    """
    if not ob.modifiers:
        return ob.data, "base", None
    deps = bpy.context.evaluated_depsgraph_get()
    avaliado = ob.evaluated_get(deps)
    return avaliado.to_mesh(), "avaliado", avaliado


def aplicar_modificadores(ob):
    """Grava os modificadores na malha, em ordem, e limpa a pilha.

    E o que a fonte da carta ja tem (a malha esta gravada, sem modificador
    vivo), e por isso que `centralizar` e `normalizar` funcionam nela: elas
    mexem em `ob.data`. Numa peca que vem de modificador, sem aplicar antes,
    centralizar a base centraria o PERFIL (que mora em x >= 0, com o centro em
    x = raio/2) e o torno giraria em volta do eixo errado.
    """
    nomes = [m.name for m in ob.modifiers]
    for nome in nomes:
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=nome)
    return nomes


def caixa_da_malha(malha):
    """Caixa da malha MEDIDA, e nao a do objeto: `ob.dimensions` de um objeto
    com modificador e a caixa do modificador, e a da base e a do perfil."""
    xs = [v.co.x for v in malha.vertices]
    ys = [v.co.y for v in malha.vertices]
    zs = [v.co.z for v in malha.vertices]
    return (
        max(xs) - min(xs) if xs else 0.0,
        max(ys) - min(ys) if ys else 0.0,
        max(zs) - min(zs) if zs else 0.0,
    )


def medir(ob):
    """A medicao que a R16 exige: face, ngon, triangulo e malha fechada.

    Roda na FONTE, antes de qualquer transformacao: e ali que o n-gon ainda
    existe. No `.glb` ele ja virou triangulo e o defeito sumiu.
    """
    malha, origem, avaliado = malha_medida(ob)
    bm = bmesh.new()
    bm.from_mesh(malha)
    lados = Counter(len(f.verts) for f in bm.faces)
    faces_por_aresta = {}
    area = 0.0
    for f in bm.faces:
        area += f.calc_area()
        for e in f.edges:
            faces_por_aresta[e] = faces_por_aresta.get(e, 0) + 1
    degeneradas = sum(1 for f in bm.faces if f.calc_area() < 1e-12)
    r = {
        "origem_da_medida": origem,
        "modificadores_vivos": [m.name for m in ob.modifiers],
        "verts": len(malha.vertices),
        "faces": len(malha.polygons),
        "quads": lados.get(4, 0),
        "tris": lados.get(3, 0),
        "ngons": {n: q for n, q in sorted(lados.items()) if n > 4},
        "degeneradas": degeneradas,
        "aresta_em_1_ou_mais": sum(
            1 for v in faces_por_aresta.values() if v != 2
        ),
        "fechada": bool(faces_por_aresta) and set(faces_por_aresta.values()) == {2},
        "triangulos_artefato": sum(max(0, len(f.verts) - 2) for f in bm.faces),
        "area_mm2": round(area * 1e6, 6),
        "caixa": [round(v, 9) for v in caixa_da_malha(malha)],
    }
    bm.free()
    if avaliado is not None:
        avaliado.to_mesh_clear()
    return r


def portao(m):
    """O que recusa a publicacao. Triangulo NAO recusa: e face legitima."""
    erros = []
    if not m["faces"]:
        erros.append(
            "a medicao viu 0 faces: o objeto nao tem geometria onde ela mediu "
            "(origem=%s, modificadores=%s). Medir a base de um objeto com "
            "modificador mede o PERFIL, nao a peca."
            % (m["origem_da_medida"], m["modificadores_vivos"])
        )
        return erros
    if m["ngons"]:
        erros.append(
            "n-gon presente (%s): em contorno con cavo a diagonal e escolhida na "
            "hora da publicacao" % m["ngons"]
        )
    if m["degeneradas"]:
        erros.append("%d face(s) degenerada(s) (area 0)" % m["degeneradas"])
    if not m["fechada"]:
        erros.append(
            "malha aberta ou nao-manifold: %d aresta(s) fora de 2 faces"
            % m["aresta_em_1_ou_mais"]
        )
    return erros


def centro_malha(ob):
    """Centro do volume da malha em coordenadas de objeto (e nao do mundo)."""
    vs = [v.co for v in ob.data.vertices]
    return Vector((
        (min(v.x for v in vs) + max(v.x for v in vs)) / 2.0,
        (min(v.y for v in vs) + max(v.y for v in vs)) / 2.0,
        (min(v.z for v in vs) + max(v.z for v in vs)) / 2.0,
    ))


def centralizar(ob):
    """Zera a origem do objeto E o volume da malha.

    Sao as DUAS coisas: o `.glb` leva a transformacao do no junto com a malha,
    entao uma malha centrada num objeto que esta em (0, 0, 0,043) chega
    deslocada em 0,043 — que foi exatamente o defeito que chegou no jogo, com a
    faixa marrom aparecendo acima da moldura.
    """
    c = centro_malha(ob)
    if c.length > 0.0:
        for v in ob.data.vertices:
            v.co -= c
        ob.data.update()
    ob.location = (0.0, 0.0, 0.0)
    ob.rotation_euler = (0.0, 0.0, 0.0)
    return c


def centro_mundo(ob):
    """Centro do volume da malha no espaco de mundo: o que o jogo vai ver."""
    return ob.matrix_world @ centro_malha(ob)


def normalizar(ob, largura=LARGURA_JOGO, girar_x=0.0):
    """Escala pela largura MEDIDA, recentra, gira e VERIFICA.

    A normalizacao e pela largura medida da propria malha, e nao por um numero
    escrito aqui: a medida e da mesa (D70), e quem carrega o `.glb` reclama com
    `assert` se o que chegou nao bater.

    `girar_x` gira a peca em torno do X ANTES de aplicar, e existe porque o
    JOGO tem Y para cima: uma peca achatada (a moeda, thickness no eixo do
    torno) precisa chegar com a espessura em Y, ou o jogo tem de corrigir a
    pose na mao. Girar aqui e nao la porque a fonte fica na pose de
    modelagem, que e a pose em que a pessoa esta olhando (R15).
    """
    antes = list(ob.dimensions)
    if antes[0] <= 0.0:
        raise ValueError("largura zero: a peca nao foi construida")
    fator = largura / antes[0]
    centralizar(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    if abs(girar_x) > 0.0:
        ob.rotation_euler = (girar_x, 0.0, 0.0)
    ob.scale = (ob.scale.x * fator, ob.scale.y * fator, ob.scale.z * fator)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    bpy.context.view_layer.update()
    resto = centro_mundo(ob)
    if resto.length > 1e-6:
        raise ValueError(
            "a peca nao ficou centrada na origem: centro no mundo=%s. O corpo "
            "entraria deslocado em relacao ao que o jogo cola nele." % (resto,)
        )
    return {"antes": antes, "fator": fator, "girar_x_graus": girar_x * 57.29577951308232,
            "depois": list(ob.dimensions), "centro_mundo": [0.0, 0.0, 0.0],
            "location": list(ob.location)}


def conferir_artefato(caminho, largura=LARGURA_JOGO, altura=None):
    """Le o `.glb` e confere o que o JOGO vai ver de verdade.

    Confere os vertices do arquivo, sem passar pelo importador: foi assim que
    apareceu o defeito que a centralizacao so em memoria nao pegava.

    O que NAO da para conferir no artefato: malha fechada (o glTF quebra o
    vertice por canto). E o que a centragem: o `.glb` leva a transformacao do no
    junto com a malha, entao uma malha centrada num objeto deslocado chega
    torta, e o sintoma no jogo e a peca aparecendo fora da moldura.
    """
    with open(caminho, "rb") as fh:
        bruto = fh.read()
    if bruto[:4] != b"glTF":
        raise ValueError("nao e glb: %s" % caminho)
    tamanho_json, _ = struct.unpack_from("<II", bruto, 12)
    doc = json.loads(bruto[20:20 + tamanho_json].decode("utf-8"))
    off_bin = 20 + tamanho_json
    tamanho_bin, _ = struct.unpack_from("<II", bruto, off_bin)
    buf = bruto[off_bin + 8: off_bin + 8 + tamanho_bin]

    tris = 0
    xs, ys, zs = [], [], []
    materiais = set()
    for m in doc.get("meshes", []):
        for pr in m.get("primitives", []):
            tris += doc["accessors"][pr["indices"]]["count"] // 3
            if "material" in pr:
                materiais.add(doc["materials"][pr["material"]].get("name", "?"))
            acc = doc["accessors"][pr["attributes"]["POSITION"]]
            bv = doc["bufferViews"][acc["bufferView"]]
            base = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
            for k in range(acc["count"]):
                x, y, z = struct.unpack_from("<fff", buf, base + k * 12)
                xs.append(x); ys.append(y); zs.append(z)

    caixa = {
        "x": (min(xs), max(xs)) if xs else (0.0, 0.0),
        "y": (min(ys), max(ys)) if ys else (0.0, 0.0),
        "z": (min(zs), max(zs)) if zs else (0.0, 0.0),
    }
    centro = {
        "x": (caixa["x"][0] + caixa["x"][1]) / 2.0,
        "y": (caixa["y"][0] + caixa["y"][1]) / 2.0,
        "z": (caixa["z"][0] + caixa["z"][1]) / 2.0,
    }
    desvio = max(abs(centro[k]) for k in centro) if xs else 0.0
    tamanho = {k: caixa[k][1] - caixa[k][0] for k in caixa}

    erros = []
    if desvio > 1e-5:
        erros.append(
            "os vertices do artefato nao estao centrados: desvio=%g. A peca "
            "entraria deslocada em relacao ao que o jogo cola nela." % desvio
        )
    if abs(tamanho["x"] - largura) > 1e-4:
        erros.append(
            "a largura do artefato e %g e o jogo usa %g: a peca chegaria "
            "pequena em silencio" % (tamanho["x"], largura)
        )
    if altura is not None and abs(tamanho["y"] - altura) > 1e-4:
        erros.append(
            "a altura/espessura do artefato e %g e o jogo usa %g"
            % (tamanho["y"], altura)
        )
    for n in doc.get("nodes", []):
        if n.get("translation") or n.get("rotation") or n.get("scale"):
            erros.append(
                "o no %s tem transformacao (%s): o artefato tem de entrar com a "
                "identidade, senao a peca chega deslocada"
                % (n.get("name"), n.get("translation") or n.get("rotation")
                   or n.get("scale"))
            )

    return {
        "triangulos": tris,
        "verts": len(xs),
        "materiais": sorted(materiais),
        "caixa": {k: [round(v, 9) for v in caixa[k]] for k in caixa},
        "tamanho": {k: round(tamanho[k], 9) for k in tamanho},
        "centro": {k: round(centro[k], 9) for k in centro},
        "desvio_do_centro": round(desvio, 9),
        "nos": [n.get("name") for n in doc.get("nodes", [])],
        "erros": erros,
    }

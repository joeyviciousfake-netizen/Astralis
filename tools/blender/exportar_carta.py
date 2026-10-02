"""exportar_carta.py — publica a carta de duelo: normaliza a medida e mede a malha.

O que esta ferramenta faz, e por que cada parte existe:

1. **Mede a malha e recusa n-gon (R16).** Triangulo e quad valem; face de mais
   de 4 lados nao, porque em contorno con cavo as diagonais nao estao em lugar
   nenhum e quem exporta escolhe na hora. A malha tambem tem de estar fechada
   (toda aresta em exatamente 2 faces).
2. **Normaliza a largura para 1,0.** O jogo trabalha na unidade em que a
   largura da carta e 1,0; a fonte esta em milimetro real (1 unidade do
   Blender = 1 metro, entao a carta vem com 0,059 de largura). Sem esta
   normalizacao o artefato chega 1/0,059 = 16,95 vezes pequeno em silencio.
   A normalizacao e pela LARGURA MEDIDA da propria malha, e nao por um numero
   escrito aqui: a medida da carta e da mesa (D70), e quem carrega o .glb
   reclama com `assert` se o que chegou nao bater. Aqui nao ha copia do numero.
3. **Centra a origem.** O corpo da carta no jogo e um `BoxMesh`, que vem
   centrado na origem do no. A fonte tem a base apoiada em Z = 0, entao sem
   recentrar o artefato entraria 43% da altura acima de onde a mesa coloca a
   carta.
4. **Exporta so a carta.** A cena tem Camera e Light; elas nao vao no artefato.
5. **Confere o artefato lendo o proprio `.glb`.** O que o jogo vai ver e o glb,
   nao a fonte. A confericao de malha fechada NAO pode ser feita la: o glTF
   quebra o vertice por canto, entao as 2 faces que dividem uma aresta deixam
   de compartilhar indice. Por isso o portao de face roda na FONTE e o artefato
   so e conferido no que sobrevive a quebra (triangulo e vertice).

Como rodar (da raiz do repo), com o Blender aberto e a carta visivel:

    1. primeiro abrir o Blender pelo launcher:
       .\\tools\\blender\\abrir_blender.ps1 -Blend astralis\\assets\\3d\\fonte\\carta_de_duelo.blend
    2. depois, dentro do Blender (Scripting, ou pelo MCP), rodar o `exportar()`.

A ferramenta nao abre arquivo: ela publica o que ja esta aberto. Da linha de
comando quem abre e o proprio Blender:

    blender --background astralis\\assets\\3d\\fonte\\carta_de_duelo.blend
             --python tools\\blender\\exportar_carta.py
"""

import json
import os
import sys
from collections import Counter

import bmesh
import bpy
from mathutils import Vector

# --- dono dos caminhos (o repo, nao o script) -------------------------------
AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
FONTE_PADRAO = os.path.join(RAIZ, "astralis", "assets", "3d", "fonte", "carta_de_duelo.blend")
ARTEFATO = os.path.join(RAIZ, "astralis", "assets", "3d", "carta_de_duelo.glb")

# A largura que o jogo usa: a mesa e a unica dona da medida (D70), e ela
# trabalha com a largura da carta = 1,0. Aqui so o alvo da normalizacao.
LARGURA_JOGO = 1.0
NOMES_ARTEFATO = ("Carta",)


def medir(ob):
    """A medicao que a R16 exige: face, ngon, triangulo e malha fechada."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    lados = Counter(len(f.verts) for f in bm.faces)
    faces_por_aresta = {}
    area = 0.0
    for f in bm.faces:
        area += f.calc_area()
        for e in f.edges:
            faces_por_aresta[e] = faces_por_aresta.get(e, 0) + 1
    degeneradas = sum(1 for f in bm.faces if f.calc_area() < 1e-12)
    r = {
        "verts": len(ob.data.vertices),
        "faces": len(ob.data.polygons),
        "quads": lados.get(4, 0),
        "tris": lados.get(3, 0),
        "ngons": {n: q for n, q in sorted(lados.items()) if n > 4},
        "degeneradas": degeneradas,
        "aresta_em_1_ou_mais": sum(
            1 for v in faces_por_aresta.values() if v != 2
        ),
        "fechada": set(faces_por_aresta.values()) == {2},
        "triangulos_artefato": sum(max(0, len(f.verts) - 2) for f in bm.faces),
        "caixa": [round(v, 9) for v in ob.dimensions],
    }
    bm.free()
    return r


def portao(m):
    """O que recusa a exportacao. Triangulo NAO recusa: e face legitima."""
    erros = []
    if m["ngons"]:
        erros.append(
            "n-gon presente (%s): em contorno con cavo a diagonal e escolhida na "
            "hora da exportacao" % m["ngons"]
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
    puca marrom aparecendo acima da moldura.
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
    """Centro do volume da malha no espaço de mundo: o que o jogo vai ver."""
    return ob.matrix_world @ centro_malha(ob)



def normalizar(ob, largura=LARGURA_JOGO):
    """Escala pela largura medida, recentra e VERIFICA. Devolve o que mediu.

    A verificacao no fim e o que impede o erro de voltar: uma malha recentrada
    a conta e um `.glb` com a peca deslocada chegaram juntos uma vez, porque o
    `origin_set` nao centralizou a malha que o Bevel entregou.
    """
    antes = list(ob.dimensions)
    if antes[0] <= 0.0:
        raise ValueError("largura zero: a carta nao foi construida")
    fator = largura / antes[0]
    centralizar(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    ob.scale = (ob.scale.x * fator, ob.scale.y * fator, ob.scale.z * fator)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    bpy.context.view_layer.update()
    resto = centro_mundo(ob)
    if resto.length > 1e-6:
        raise ValueError(
            "a carta nao ficou centrada na origem: centro no mundo=%s. O corpo "
            "entraria deslocado em relacao as imagens que ficam coladas nele."
            % (resto,)
        )
    return {"antes": antes, "fator": fator, "depois": list(ob.dimensions),
            "centro_mundo": [0.0, 0.0, 0.0],
            "location": list(ob.location)}



def conferir_artefato(caminho, largura=LARGURA_JOGO, altura=None):
    """Le o `.glb` e confere o que o JOGO vai ver de verdade.

    Confere os vertices do arquivo, sem passar pelo importador: foi assim que
    apareceu o defeito que a centralizacao em memoria nao pegava.

    O que NAO da para conferir no artefato: malha fechada. O glTF quebra o
    vertice por canto (normais e UV por face), entao as 2 faces que dividem uma
    aresta deixam de compartilhar indice. Por isso o portao de face roda na
    FONTE, e aqui so o que sobrevive a essa quebra.

    A CENTRAGEM e conferida aqui porque o `.glb` leva a transformacao do no
    junto com a malha: uma malha centrada num objeto deslocado chega torta, e o
    sintoma no jogo e a peca aparecendo fora da moldura, longe da origem.
    """
    import struct

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
            "os vertices do artefato nao estao centrados: desvio=%g. O corpo "
            "entraria deslocado em relacao as imagens coladas nele." % desvio
        )
    if abs(tamanho["x"] - largura) > 1e-4:
        erros.append(
            "a largura do artefato e %g e o jogo usa %g: a peca 17x menor "
            "chegaria em silencio" % (tamanho["x"], largura)
        )
    if altura is not None and abs(tamanho["y"] - altura) > 1e-4:
        erros.append(
            "a altura do artefato e %g e o jogo usa %g" % (tamanho["y"], altura)
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



def escolher(objetos):
    for nome in NOMES_ARTEFATO:
        achado = objetos.get(nome)
        if achado is not None:
            return achado
    raise ValueError(
        "nenhum objeto chamado %s na cena; tem %s"
        % (NOMES_ARTEFATO, sorted(objetos.keys()))
    )


def exportar(fonte=None):
    # A ferramenta NAO abre arquivo. Quem abre e o launcher (na frente da
    # pessoa, R15) ou o proprio Blender na linha de comando. Abrir de dentro
    # daqui deixa o contexto do view layer obsoleto e o exportador quebra com
    # "'Context' object has no attribute 'active_object'".
    fonte = bpy.data.filepath
    if not fonte:
        raise ValueError(
            "nenhum arquivo aberto: abra a fonte antes "
            "(.\\tools\\blender\\abrir_blender.ps1 -Blend %s)" % FONTE_PADRAO
        )

    cartoes = [o for o in NOMES_ARTEFATO if o in bpy.data.objects]
    for nome in list(bpy.data.objects.keys()):
        if nome not in NOMES_ARTEFATO:
            bpy.data.objects.remove(bpy.data.objects[nome], do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)

    carta = escolher(bpy.data.objects)

    # o portao roda na FONTE, antes de qualquer transformacao: e aqui que o
    # n-gon ainda existe. No .glb ele ja virou triangulo e o defeito sumiu.
    medido = medir(carta)
    erros = portao(medido)
    relatorio = {
        "fonte": fonte,
        "artefato": ARTEFATO,
        "medida_fonte_mm": medido,
        "normalizacao": None,
        "erros": erros,
    }
    if erros:
        print("PORTAO RECUSOU:")
        for e in erros:
            print("  -", e)
        return relatorio

    # A normalizacao roda numa COPIA: a fonte continua em milimetro real, que e
    # como se modela, e exportar nao pode mexer no modelo de quem esta na frente
    # da tela (R15).
    #
    # O nome da malha viaja no .glb e e o que aparece no import. O Blender
    # uniquifica nome repetido, entao a original empresta o nome do objeto E da
    # malha durante o export e devolve depois: sem isso o artefato sai como
    # "Carta.001", que nao diz qual peca e.
    nome = carta.name
    nome_malha = carta.data.name
    copia = carta.copy()
    copia.data = carta.data.copy()
    carta.users_collection[0].objects.link(copia)
    carta.name = "_origem_" + nome
    carta.data.name = "_origem_" + nome_malha
    copia.name = nome
    copia.data.name = nome

    relatorio["normalizacao"] = normalizar(copia)
    relatorio["medida_normalizada"] = medir(copia)

    bpy.ops.object.select_all(action="DESELECT")
    copia.select_set(True)
    bpy.context.view_layer.objects.active = copia
    bpy.context.view_layer.update()

    os.makedirs(os.path.dirname(ARTEFATO), exist_ok=True)
    try:
        _exportar_glb()
        relatorio["bytes"] = os.path.getsize(ARTEFATO)
        relatorio["artefato_lido"] = conferir_artefato(
            ARTEFATO, LARGURA_JOGO, relatorio["medida_normalizada"]["caixa"][2])
        relatorio["erros"] = erros + relatorio["artefato_lido"]["erros"]
        if relatorio["erros"]:
            print("PORTAO RECUSOU O ARTEFATO:")
            for e in relatorio["erros"]:
                print("  -", e)
    finally:
        # A limpeza roda mesmo com o export caindo: deixar a copia e o nome
        # emprestado na cena seria pior que o erro que interrompeu.
        malha_copia = copia.data
        bpy.data.objects.remove(copia, do_unlink=True)
        if malha_copia.users == 0:
            bpy.data.meshes.remove(malha_copia)
        carta.name = nome
        carta.data.name = nome_malha
        for me in list(bpy.data.meshes):
            if me.users == 0:
                bpy.data.meshes.remove(me)

    print(json.dumps(relatorio, indent=2, ensure_ascii=False))
    return relatorio


def _exportar_glb():
    bpy.ops.export_scene.gltf(
        filepath=ARTEFATO,
        check_existing=False,
        export_format="GLB",
        use_selection=True,
        export_apply=True,          # grava a suavizacao do arco como aresta dura
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_animations=False,
        export_cameras=False,
        export_lights=False,
        export_extras=True,
        export_draco_mesh_compression_enable=False,
        export_draco_position_quantization=14,
        filter_glob="*.glb",
    )


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    exportar(argv[0] if argv else None)
"""exportar_assets.py — exporta os assets 3D do jogo a partir do .blend.

DONO: QA/Integration (tools/ = script de dev, nunca jogo — doc 02.7).
O QUE ELE E: o caminho UNICO do Blender para o repositorio. Nao existe outro
lugar onde um .glb e produzido, e nenhum numero do mesh vive no codigo do
jogo — o manifesto e a fonte (a mesma ideia do D50 na arena: um dado so, e a
consequencia e que o teste pode cravar a igualdade).

COMO FUNCIONA (duas metades):
  1. BLENDER (headless) abre o .blend, que e a FONTE do mesh, e exporta o
     .glb com as opcoes fixas deste arquivo (nada de "ajustar no Godot
     depois" — foi o APROXIMA_MAGIA_* que o D49 apagou).
  2. O MESMO Blender reimporta o .glb recem-gerado e mede. O que ele mede
     precisa bater com o manifesto, senao o script falha com codigo 1. E por
     isso que o manifesto nao e um comentario: ele crava o resultado.

COMO RODAR (da raiz do repo):
  $env:BLENDER = "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe"
  & $env:BLENDER --background --factory-startup `
      --python tools/blender/exportar_assets.py -- exportar

  Modo `medir` (autorar um asset novo): exporta, imprime as medidas e NAO
  falha — e o que voce usa para preencher o manifesto com os numeros que o
  jogo vai ver.

CONVENCOES (doc 17, travadas aqui e no manifesto):
  - 1 unidade Blender = 1 unidade de mundo do jogo = 1 largura de carta
  - Y para cima no jogo; o exportador glTF converte o Z do Blender (yup=True)
  - origem na BASE e no CENTRO: y=0 no chao, x/z centrados, para o objeto
    pousar no plano do campo sem nenhum ajuste
  - um material por asset, chamado mat_<id>
"""

import json
import os
import struct
import sys

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DIR_ASSETS = os.path.join(RAIZ, "astralis", "assets", "3d")
MANIFESTO = os.path.join(DIR_ASSETS, "manifest.json")
SCHEMA_VERSION = 1

GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A


def blender_path():
    for p in (
        os.environ.get("BLENDER"),
        r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
    ):
        if p and os.path.exists(p):
            return p
    return ""


# ---------- medir o ARTEFATO: o .glb em espaco de jogo (Y para cima) ----------

def ler_glb_json(caminho):
    """Le o chunk JSON de um .glb. Sem Blender e sem dependencia nenhuma:
    o glTF ja e Y para cima, entao os numeros sao os que o jogo ve."""
    with open(caminho, "rb") as f:
        dados = f.read()
    magic, versao, tamanho = struct.unpack_from("<III", dados, 0)
    if magic != GLB_MAGIC:
        raise ValueError("%s nao e um GLB (magic 0x%08X)" % (caminho, magic))
    pos = 12
    doc = None
    while pos < tamanho:
        tam, tipo = struct.unpack_from("<II", dados, pos)
        pos += 8
        if tipo == CHUNK_JSON:
            doc = json.loads(dados[pos:pos + tam].decode("utf-8"))
        pos += tam
    if doc is None:
        raise ValueError("%s sem chunk JSON" % caminho)
    return doc


def _transform_do_no(no):
    """A convencao do projeto e o .glb entrar SEM transform no no (identidade).
    Se vier transform, o Godot mostraria o objeto deslocado/escalado e
    alguem iria 'consertar' no codigo do jogo — que e exatamente o defeito
    que o D49 apagou. Entao a medicao RECUSA, e nao corrige."""
    if "matrix" in no:
        m = no["matrix"]
        if any(abs(v - (1.0 if i % 5 == 0 or i % 5 == 4 else 0.0)) > 1e-6 for i, v in enumerate(m)):
            return False
    if any(abs(float(no.get(k, 0.0))) > 1e-6 for k in ("translation", "rotation")):
        return False
    if abs(float(no.get("scale", 1.0)) - 1.0) > 1e-6:
        return False
    return True


def medir_glb(caminho_glb):
    """Mede o .glb como o jogo vai ver: triangulos, vertices, caixa em Y para
    cima e nomes de material. Le o arquivo, nao o Blender — porque medir
    reimportando no Blender devolveria os eixos do Blender (a conversao do
    glTF se cancela no ida e volta) e a trava passaria errado."""
    doc = ler_glb_json(caminho_glb)
    acessores = doc.get("accessors", [])
    nos = doc.get("nodes", [])
    materiais = doc.get("materials", [])

    malhas = 0
    tris = 0
    verts = 0
    minimo = [1e9, 1e9, 1e9]
    maximo = [-1e9, -1e9, -1e9]
    nomes = []
    identidade = True

    for no in nos:
        if "mesh" not in no:
            continue
        malhas += 1
        identidade = identidade and _transform_do_no(no)
        for prim in (doc.get("meshes", [])[no["mesh"]] or {}).get("primitives", []):
            pos = acessores[prim["attributes"]["POSITION"]]
            verts += int(pos["count"])
            if "indices" in prim:
                tris += int(acessores[prim["indices"]]["count"]) // 3
            else:
                tris += max(0, int(pos["count"]) - 2) // 1
            if "material" in prim and materiais:
                nome = materiais[int(prim["material"])].get("name", "")
                if nome and nome not in nomes:
                    nomes.append(nome)
            if "min" in pos and "max" in pos:
                for i in range(3):
                    minimo[i] = min(minimo[i], float(pos["min"][i]))
                    maximo[i] = max(maximo[i], float(pos["max"][i]))

    if malhas == 0:
        raise ValueError("%s nao tem nenhuma malha" % caminho_glb)

    caixa = {}
    for i, eixo in enumerate("xyz"):
        caixa[eixo] = [round(minimo[i], 4), round(maximo[i], 4)]

    return {
        "malhas": malhas,
        "vertices": verts,
        "triangulos": tris,
        "materiais": sorted(nomes),
        "caixa": caixa,
        "no_sem_transform": identidade,
    }



def exportar_um(caminho_blend, caminho_glb):
    """Exporta com as opcoes FIXAS do pipeline. Tudo explicito de proposito:
    opcao implicita do Blender 5.2 que mudar entre versoes = glb diferente."""
    import bpy

    bpy.ops.wm.open_mainfile(filepath=caminho_blend)
    bpy.ops.export_scene.gltf(
        filepath=caminho_glb,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_skins=False,
        export_morph=False,
    )
    return os.path.getsize(caminho_glb)


# ---------- AUDITAR A MALHA: a fonte e o artefato, por lados diferentes ----------

def auditar_fonte_malha():
    """A malha tem que entrar SANA em qualquer asset. Roda DENTRO do Blender,
    com bmesh, sobre a cena aberta.

    POR QUE A FONTE E NAO O .glb: o glTF so tem triangulos, entao o exportador
    ja triangularizou um n-gon antes de ele virar arquivo — no artefato o n-gon
    nao existe mais e o defeito some de vista. So a fonte mostra.

    O QUE E ERRO e o que e AVISO:
      ERRO  - face com mais de 4 lados (o n-gon con cavo, cuja diagonal e
              escolhida na hora da exportacao: a mesma .blend daria geometrias
              diferentes em ferramentas diferentes)
      ERRO  - face degenerada (area zero), face repetida, vertice solto, aresta
              de bordo (malha aberta) ou aresta com mais de 2 faces (nao-manifold)
      AVISO - nenhuma face de 4 lados (so triangulos): nao e erro, porque nem
              toda peca precisa de quad, mas o asset de teste deveria ter
    """
    import bpy
    import bmesh
    from collections import defaultdict

    problemas = []
    avisos = []
    cena = bpy.context.scene
    for ob in cena.objects:
        if ob.type != "MESH":
            continue
        nome = ob.name
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.faces.ensure_lookup_table()

        hist = defaultdict(int)
        for f in bm.faces:
            hist[len(f.verts)] += 1

        # n-gon: o defeito que o projeto nao aceita
        for f in bm.faces:
            if len(f.verts) > 4:
                problemas.append("%s: face ngon de %d lados (maximo 4). "
                                 "Em face con cava a diagonal e escolhida na "
                                 "exportacao, entao a geometria nao e "
                                 "reproduzivel." % (nome, len(f.verts)))
                break

        # degenerada / repetida / vertice solto
        vistas = set()
        for f in bm.faces:
            if f.calc_area() <= 1e-12:
                problemas.append("%s: face degenerada (area 0)" % nome)
                break
            chave = tuple(sorted(v.index for v in f.verts))
            if chave in vistas:
                problemas.append("%s: face repetida (mesmos vertices)" % nome)
                break
            vistas.add(chave)
        if any(len(f.verts) < 3 for f in bm.faces):
            problemas.append("%s: face com menos de 3 vertices" % nome)

        usados = {v.index for f in bm.faces for v in f.verts}
        soltos = [v for v in bm.verts if v.index not in usados]
        if soltos:
            problemas.append("%s: %d vertice(s) solto(s) — posicao que nenhuma "
                             "face usa (peso morto)" % (nome, len(soltos)))

        # fechada e manifold
        arestas = defaultdict(int)
        for f in bm.faces:
            vs = list(f.verts)
            for i in range(len(vs)):
                a, b = vs[i], vs[(i + 1) % len(vs)]
                arestas[(min(a.index, b.index), max(a.index, b.index))] += 1
        cont = defaultdict(int)
        for qtd in arestas.values():
            cont[qtd] += 1
        if cont.get(1):
            problemas.append("%s: %d aresta(s) de bordo — a malha esta ABERTA"
                             % (nome, cont[1]))
        if any(q > 2 for q in cont):
            problemas.append("%s: aresta com mais de 2 faces — nao-manifold" % nome)

        if not hist.get(4):
            avisos.append("%s: nenhuma face de 4 lados (so triangulos)" % nome)

        area = sum(f.calc_area() for f in bm.faces)
        bm.free()
        # a area total e a invariante entre a fonte e o artefato: o export nao
        # muda area, entao a soma das areas tem que bater nas duas pontas
        return problemas, avisos, area
    return problemas, avisos, 0.0


def auditar_artefato_malha(caminho_glb, area_esperada):
    """Confere o .glb como o jogo vai ver. Duas coisas que so existem aqui:
    a normal gravada de cada triangulo, e a area total (que tem que ser a mesma
    da fonte)."""
    doc = ler_glb_json(caminho_glb)
    with open(caminho_glb, "rb") as f:
        dados = f.read()
    bin_ = b""
    pos = 12
    magic, versao, tamanho = struct.unpack_from("<III", dados, 0)
    while pos < tamanho:
        tam, tipo = struct.unpack_from("<II", dados, pos)
        pos += 8
        if tipo == 0x004E4942:
            bin_ = dados[pos:pos + tam]
        pos += tam

    comp = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2),
            5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
    ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
    acessores = doc.get("accessors", [])

    def acc(i):
        a = acessores[i]
        bv = doc["bufferViews"][a["bufferView"]]
        fmt, _ = comp[int(a["componentType"])]
        larg = ncomp[a["type"]]
        base = int(bv.get("byteOffset", 0)) + int(a.get("byteOffset", 0))
        bruto = struct.unpack_from("<" + fmt * (int(a["count"]) * larg), bin_, base)
        return [tuple(bruto[k * larg:(k + 1) * larg]) for k in range(int(a["count"]))]

    problemas = []
    area_total = 0.0
    for no in doc.get("nodes", []):
        if "mesh" not in no:
            continue
        for prim in doc["meshes"][int(no["mesh"])].get("primitives", []):
            P = acc(prim["attributes"]["POSITION"])
            if "NORMAL" not in prim["attributes"]:
                problemas.append("primitiva sem NORMAL: o jogo vai recalcular e "
                                 "pode ficar diferente do que o Blender viu")
                continue
            N = acc(prim["attributes"]["NORMAL"])
            if "indices" not in prim:
                continue
            I = acc(prim["indices"])
            for t in range(len(I) // 3):
                ia, ib, ic = int(I[3 * t][0]), int(I[3 * t + 1][0]), int(I[3 * t + 2][0])
                a, b, c = P[ia], P[ib], P[ic]
                u = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
                v = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
                cr = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2],
                      u[0] * v[1] - u[1] * v[0])
                m = (cr[0] ** 2 + cr[1] ** 2 + cr[2] ** 2) ** 0.5
                if m <= 1e-12:
                    problemas.append("triangulo %d degenerado no artefato" % t)
                    continue
                area_total += 0.5 * m
                geo = (cr[0] / m, cr[1] / m, cr[2] / m)
                if max(abs(N[ia][k] - geo[k]) for k in range(3)) > 1e-3:
                    problemas.append("triangulo %d: a normal gravada nao bate com a "
                                     "geometrica (=%s vs %s) — e este que faz "
                                     "'alguns poligonos parecerem errados'"
                                     % (t, tuple(round(x, 3) for x in N[ia]),
                                        tuple(round(x, 3) for x in geo)))
                    break

    if area_esperada > 0:
        erro = abs(area_total - area_esperada) / area_esperada
        if erro > 1e-3:
            problemas.append("area total: fonte=%.6f artefato=%.6f (erro %.4f%%) — "
                             "a triangulacao perdeu ou vazou geometria"
                             % (area_esperada, area_total, erro * 100))
    return problemas, area_total


def comparar(asset, medido):
    """O manifesto e a trava. Devolve a lista de divergencias (vazia = bate)."""
    erros = []
    for chave in ("triangulos", "vertices", "malhas"):
        if int(asset.get(chave, -1)) != int(medido[chave]):
            erros.append("%s: manifesto=%s medido=%s" % (chave, asset.get(chave), medido[chave]))
    if sorted(asset.get("materiais", [])) != medido["materiais"]:
        erros.append("materiais: manifesto=%s medido=%s" % (asset.get("materiais"), medido["materiais"]))
    if not medido["no_sem_transform"]:
        erros.append("o no do .glb tem transform: a convencao e entrar com identidade")
    for eixo in "xyz":
        esp = asset.get("caixa", {}).get(eixo)
        if esp is None:
            erros.append("caixa.%s: ausente no manifesto" % eixo)
            continue
        got = medido["caixa"][eixo]
        if abs(float(esp[0]) - got[0]) > 0.001 or abs(float(esp[1]) - got[1]) > 0.001:
            erros.append("caixa.%s: manifesto=%s medido=%s" % (eixo, esp, got))
    return erros


def main():
    modo = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "exportar"
    if not os.path.exists(MANIFESTO):
        print("ERRO: manifesto ausente em %s" % MANIFESTO)
        return 1
    with open(MANIFESTO, "r", encoding="utf-8") as f:
        dados = json.load(f)

    if int(dados.get("schema_version", 0)) != SCHEMA_VERSION:
        print("ERRO: manifest.schema_version=%s (esperado %d)" % (dados.get("schema_version"), SCHEMA_VERSION))
        return 1

    falhas = 0
    for asset in dados.get("assets", []):
        aid = asset.get("id", "?")
        blend = os.path.join(DIR_ASSETS, asset.get("blend", ""))
        glb = os.path.join(DIR_ASSETS, asset.get("glb", ""))
        if not os.path.exists(blend):
            print("[%s] ERRO: .blend ausente: %s" % (aid, blend))
            falhas += 1
            continue
        bytes_ = exportar_um(blend, glb)
        medido = medir_glb(glb)

        # AUDITORIA DA MALHA: a fonte pelo bmesh (e o unico lugar onde o n-gon
        # ainda existe) e o artefato pelo arquivo (normal gravada e area).
        probs_fonte, avisos_fonte, area_fonte = auditar_fonte_malha()
        probs_art, area_art = auditar_artefato_malha(glb, area_fonte)
        malha_ok = not probs_fonte and not probs_art

        linha = "[%s] %d tris | %d verts | %d malhas | caixa x%s y%s z%s | %s | %.0f KB" % (
            aid, medido["triangulos"], medido["vertices"], medido["malhas"],
            medido["caixa"]["x"], medido["caixa"]["y"], medido["caixa"]["z"],
            ",".join(medido["materiais"]), bytes_ / 1024.0)

        if modo == "medir":
            print(linha)
            print("        (medir: manifesto NAO foi conferido)")
            for p in probs_fonte + probs_art:
                print("        ! %s" % p)
            for a in avisos_fonte:
                print("        ~ %s" % a)
            continue

        erros = comparar(asset, medido)
        if not malha_ok:
            falhas += 1
            print("[%s] MALHA NAO SANA — o asset nao entra no jogo assim:" % aid)
            for p in (probs_fonte + probs_art)[:12]:
                print("        ! %s" % p)
        if erros:
            falhas += 1
            print("[%s] DIVERGENCIA — o manifesto nao e o que o Blender exporta:" % aid)
            for e in erros:
                print("        - %s" % e)
        if not erros and malha_ok:
            print(linha)
            print("        manifesto OK | malha sana (area fonte=%.6f artefato=%.6f)"
                  % (area_fonte, area_art))
        for a in avisos_fonte:
            print("        ~ %s" % a)

    if modo == "medir":
        return 0
    if falhas:
        print("FALHOU: %d asset(s) com divergencia. O manifest mente sobre o .blend." % falhas)
        return 1
    print("OK: %d asset(s) exportados e medidos batendo com o manifesto." % len(dados.get("assets", [])))
    return 0


if __name__ == "__main__":
    codigo = main()
    print("__EXIT__%d" % codigo)
    sys.stdout.flush()
    try:
        sys.exit(codigo)
    except SystemExit:
        raise

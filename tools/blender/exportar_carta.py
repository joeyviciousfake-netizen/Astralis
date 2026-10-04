"""exportar_carta.py — publica a carta de duelo: normaliza a medida e mede a malha.

O que esta ferramenta faz, e por que cada parte existe:

1. **Mede a malha e recusa n-gon (R16).** Triangulo e quad valem; face de mais
   de 4 lados nao, porque em contorno con cavo as diagonais nao estao em lugar
   nenhum e quem exporta escolhe na hora. A malha tambem tem de estar fechada
   (toda aresta em exatamente 2 faces). O portao e o de `portao_malha.py`, o
   mesmo da moeda: a R16 e uma regra so, e dois portoes divergem.
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

import bpy

# --- dono dos caminhos (o repo, nao o script) -------------------------------
AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
if AQUI not in sys.path:
    sys.path.insert(0, AQUI)

# O PORTAO tem um dono so (portao_malha.py): a R16 e uma regra so, e dois
# portoes divergem — o segundo aceitaria a malha que o primeiro reprova.
from portao_malha import (  # noqa: E402  (o sys.path acima e o que habilita)
    LARGURA_JOGO,
    centralizar,
    centro_malha,
    centro_mundo,
    conferir_artefato,
    medir,
    normalizar,
    portao,
)

FONTE_PADRAO = os.path.join(RAIZ, "astralis", "assets", "3d", "fonte", "carta_de_duelo.blend")
ARTEFATO = os.path.join(RAIZ, "astralis", "assets", "3d", "carta_de_duelo.glb")

NOMES_ARTEFATO = ("Carta",)


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
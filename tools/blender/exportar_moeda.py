"""exportar_moeda.py — publica a moeda do sorteio: normaliza a medida e mede a malha.

O que esta ferramenta faz, e por que cada parte existe:

1. **Mede a malha e recusa n-gon (R16).** O portao e o de `portao_malha.py`, o
   mesmo da carta: a R16 e uma regra so, e dois portoes divergem.
2. **Normaliza o DIAMETRO para 1,0.** A fonte esta em milimetro real (Ø 130
   mm), e o jogo trabalha na unidade em que a largura da peca e 1,0. A
   ESPESSURA nao precisa de rotacao: o exportador glTF ja converte o Z-up do
   Blender para o Y-up do glTF, e o eixo do torno (Z) e a espessura — entao ela
   ja chega no Y do artefato, que e o "para cima" do jogo. Ver `GIRO_X_GRAUS`.
3. **Centra a origem.** O volume da moeda e simetrico em Z (o topo do boss e o
   fundo do sulco ficam na mesma distancia do meio), entao centralizar e
   no-op aqui — e o portao do artefato e que diz se isso continua verdade.
4. **Exporta so a moeda.** A fonte tem Camera, Light e a LuzKey de estudio; elas
   nao vao no artefato.
5. **Confere o artefato lendo o proprio `.glb`.** O que o jogo vai ver e o glb,
   nao a fonte. A confericao de malha fechada NAO pode ser feita la: o glTF
   quebra o vertice por canto. Por isso o portao de face roda na FONTE e o
   artefato so e conferido no que sobrevive a quebra.

Como rodar (da raiz do repo), com o Blender aberto e a moeda visivel:

    1. primeiro abrir o Blender pelo launcher:
       .\\tools\\blender\\abrir_blender.ps1 -Blend astralis\\assets\\3d\\fonte\\moeda.blend
    2. depois, dentro do Blender (Scripting, ou pelo MCP), rodar o `exportar()`.

A ferramenta nao abre arquivo: ela publica o que ja esta aberto. Da linha de
comando quem abre e o proprio Blender:

    blender --background astralis\\assets\\3d\\fonte\\moeda.blend
             --python tools\\blender\\exportar_moeda.py
"""

import json
import math
import os
import sys

import bpy

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
if AQUI not in sys.path:
    sys.path.insert(0, AQUI)

from portao_malha import (  # noqa: E402  (o sys.path acima e o que habilita)
    LARGURA_JOGO,
    aplicar_modificadores,
    conferir_artefato,
    medir,
    normalizar,
    portao,
)

FONTE_PADRAO = os.path.join(RAIZ, "astralis", "assets", "3d", "fonte", "moeda.blend")
ARTEFATO = os.path.join(RAIZ, "astralis", "assets", "3d", "moeda.glb")

NOMES_ARTEFATO = ("Moeda",)

# NENHUMA rotacao, e isso e MEDIDO no artefato, nao escolhido.
# O exportador glTF ja converte o Z-up do Blender para o Y-up do glTF: o eixo do
# torno (Z, que e a espessura da moeda) JA CHEGA no Y do artefato, que e o "para
# cima" do jogo. Girar aqui de -90 graus ANULAva essa conversao e a espessura
# voltava para o Z — que foi o que aconteceu na primeira publicacao, e o que o
# portao recusou ("a altura/espessura do artefato e 1 e o jogo usa 0.246154").
# A armadilha e real: a carta passa pelo mesmo caminho e por isso o artefato dela
# tem a altura no Y e a espessura no Z.
GIRO_X_GRAUS = 0.0


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
    # pessoa, R15) ou o proprio Blender na linha de comando.
    fonte = bpy.data.filepath
    if not fonte:
        raise ValueError(
            "nenhum arquivo aberto: abra a fonte antes "
            "(.\\tools\\blender\\abrir_blender.ps1 -Blend %s)" % FONTE_PADRAO
        )

    # NAO apaga Camera/Light da cena de quem esta olhando (R15): publicar nao
    # pode mexer no modelo na frente da tela. E nao precisa — o artefato sai so
    # com o que esta SELECIONADO (`use_selection=True`) e com camera e luz
    # desligadas na publicacao, entao as luzes da fonte ficam de fora sozinhas.
    moeda = escolher(bpy.data.objects)

    # O portao roda na FONTE, antes de qualquer transformacao: e aqui que o
    # n-gon ainda existe.
    medido = medir(moeda)
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
    # como se modela, e publicar nao pode mexer no modelo de quem esta na frente
    # da tela (R15).
    nome = moeda.name
    nome_malha = moeda.data.name
    copia = moeda.copy()
    copia.data = moeda.data.copy()
    moeda.users_collection[0].objects.link(copia)
    moeda.name = "_origem_" + nome
    moeda.data.name = "_origem_" + nome_malha
    copia.name = nome
    copia.data.name = nome

    try:
        # A moeda vem de modificadores (o Torno e o Smooth by Angle), e quem
        # precisa mexer na malha e `centralizar`/`normalizar` — elas mexem em
        # `ob.data`, que aqui e so o perfil. Gravar os modificadores primeiro e
        # o que faz elas acertarem a PECA; sem isso elas centrariam o perfil e
        # o torno giraria em volta do eixo errado.
        relatorio["modificadores_gravados"] = aplicar_modificadores(copia)
        relatorio["normalizacao"] = normalizar(
            copia, LARGURA_JOGO, math.radians(GIRO_X_GRAUS))
        medido_normalizado = medir(copia)
        relatorio["medida_normalizada"] = medido_normalizado

        bpy.ops.object.select_all(action="DESELECT")
        copia.select_set(True)
        bpy.context.view_layer.objects.active = copia
        bpy.context.view_layer.update()

        os.makedirs(os.path.dirname(ARTEFATO), exist_ok=True)
        _exportar_glb()
        relatorio["bytes"] = os.path.getsize(ARTEFATO)
        # A espessura que o jogo usa para pousar a moeda no vidro sem afundar nem
        # flutuar e o Y do ARTEFATO. E ele vem do Z da FONTE (o exportador troca
        # Y e Z na conversao Z-up -> Y-up), e nao do Y: medir a indice errado
        # aqui faz o portao recusar um artefato que esta certo.
        relatorio["artefato_lido"] = conferir_artefato(
            ARTEFATO, LARGURA_JOGO, medido_normalizado["caixa"][2])
        relatorio["erros"] = erros + relatorio["artefato_lido"]["erros"]
        if relatorio["erros"]:
            print("PORTAO RECUSOU O ARTEFATO:")
            for e in relatorio["erros"]:
                print("  -", e)
    finally:
        malha_copia = copia.data
        bpy.data.objects.remove(copia, do_unlink=True)
        if malha_copia.users == 0:
            bpy.data.meshes.remove(malha_copia)
        moeda.name = nome
        moeda.data.name = nome_malha

    print(json.dumps(relatorio, indent=2, ensure_ascii=False))
    return relatorio


def _exportar_glb():
    bpy.ops.export_scene.gltf(
        filepath=ARTEFATO,
        check_existing=False,
        export_format="GLB",
        use_selection=True,
        export_apply=True,          # grava o Torno e o Smooth by Angle na malha
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",  # o Principled BSDF viaja como metal/rough PBR
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

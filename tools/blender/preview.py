r"""preview.py — a previa oficial de um asset 3D (Cycles, GPU, reproduzivel).

POR QUE ESTE SCRIPT EXISTE: o projeto precisa de PROVA de como o asset ficou,
e prova tem que ser (a) bonita o bastante para o olho achar defeito, (b) igual
todas as vezes, para dar pra comparar duas execucoes, e (c) vinda da GPU.
Render de boa em preview ad-hoc nao garante nada disso — mudava a semente, o
numero de amostras e o sampling com a pressa, e a imagem "comprovava" o que
quisesse. Aqui nada disso e livre.

O QUE ELE TRAVA:
  - CYCLES, e so Cycles (D62). A maquina tem RTX 5060; o backend e OptiX
    (medido em 2026-09-30: o Blender 5.2.2 LTS ve a 5060 em OPTIX e em CUDA).
  - GPU OBRIGATORIA por padrao: se nao achar GPU, o script FALHA em vez de
    cair para a CPU em silencio. Um "render na GPU" que virou CPU nao prova
    nada, e foi assim que a arena ganhou uma tela que ninguem via.
  - SAMPLES E SEMENTE FIXOS, denoise ligado e cenario de estudio montado pelo
    script (3 luzes + fundo). O QUE E GARANTIDO, e o que NAO E (medido em
    2026-09-30, nao assumido): o Cycles na GPU **nao e bit-exato** entre duas
    execucoes — o kernel faz soma em float nao-associativa e a ordem das
    operacoes muda com o escalonamento, entao o PNG sai com um punhado de
    bytes diferentes e uns poucos pixels na borda. Por isso o script nao
    promete "mesmos bytes": ele mede. Use `--comparar <outro.png>` e ele imprime
    quantos pixels mudaram e quanto. A garantia que vale e a geometria: o que o
    `.glb` carrega e medido contra o manifesto, nao a imagem.

COMO RODAR (da raiz do repo):
  & $env:BLENDER --background --factory-startup `
      --python tools/blender/preview.py -- --asset estrela_teste --out prev.png

  --asset <id>     asset do manifesto (docs/17 §17.2)  OU  --blend <caminho>
  --out <arquivo>  onde salvar o PNG (fora do repo: prova vai pra temp)
  --comparar <png> outra previa para comparar pixel a pixel (o metodo A/B)
  --samples <n>    padrao 256
  --res <n>        lado do quadrado, padrao 768
  --cpu            permite CPU (so para maquina sem GPU; avisa no log)

O script NUNCA salva o .blend: ele abre, mede, enquadra, renderiza e sai.
"""

import array
import hashlib
import os
import sys
import time

import bpy
from mathutils import Vector

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DIR_FONTE = os.path.join(RAIZ, "astralis", "assets", "3d", "fonte")
SEMENTE = 0
SAMPLES_PADRAO = 256
RES_PADRAO = 768
BACKENDS = ("OPTIX", "CUDA", "HIP", "ONEAPI")
FUNDO = (0.043, 0.063, 0.145, 1.0)


# ---------- argumentos ----------

def argumentos():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    d = {"asset": "", "blend": "", "out": "", "comparar": "", "samples": SAMPLES_PADRAO,
         "res": RES_PADRAO, "cpu": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--cpu":
            d["cpu"] = True
        elif a in ("--asset", "--blend", "--out", "--comparar") and i + 1 < len(argv):
            d[a[2:]] = argv[i + 1]
            i += 1
        elif a == "--samples" and i + 1 < len(argv):
            d["samples"] = int(argv[i + 1])
            i += 1
        elif a == "--res" and i + 1 < len(argv):
            d["res"] = int(argv[i + 1])
            i += 1
        i += 1
    return d


def comparar_pngs(a, b, tolerancia=1.0 / 255.0):
    """A/B de imagem: quantos pixels mudaram e quanto. E o mesmo metodo que a
    mesa usa para comparar fotos (doc 16 §16.12), aplicado na prova do asset."""
    ia = bpy.data.images.load(a)
    ib = bpy.data.images.load(b)
    try:
        if (ia.size[0], ia.size[1]) != (ib.size[0], ib.size[1]):
            return {"erro": "tamanhos diferentes: %s vs %s" % (str(ia.size), str(ib.size))}
        n = ia.size[0] * ia.size[1] * 4
        pa = array.array("f", [0.0]) * n
        pb = array.array("f", [0.0]) * n
        ia.pixels.foreach_get(pa)
        ib.pixels.foreach_get(pb)
        mudados = 0
        pior = 0.0
        soma = 0.0
        for p in range(0, n, 4):
            diferente = False
            for c in range(3):  # RGB; alpha das duas e 1.0
                d = abs(pa[p + c] - pb[p + c])
                soma += d
                if d > pior:
                    pior = d
                if d > tolerancia:
                    diferente = True
            if diferente:
                mudados += 1
        pixels = ia.size[0] * ia.size[1]
        return {
            "pixels": pixels,
            "mudados": mudados,
            "porcentagem": 100.0 * mudados / float(pixels),
            "delta_max": pior,
            "delta_medio": soma / float(max(1, pixels * 3)),
        }
    finally:
        bpy.data.images.remove(ia)
        bpy.data.images.remove(ib)


def falhar(msg):
    print("PREVIEW ERRO: %s" % msg)
    raise SystemExit(1)


# ---------- GPU: medida, nao hope ----------

def configurar_gpu(permitir_cpu):
    """Escolhe o primeiro backend que devolve uma GPU de verdade e DEIXA SÓ ela
    ligada (desligar a CPU e o que impede o render cair nela sem falar)."""
    prefs = bpy.context.preferences.addons.get("cycles")
    if prefs is None:
        falhar("o addon cycles nao esta carregado neste build do Blender")
    cp = prefs.preferences
    tentativa = []
    for backend in BACKENDS:
        try:
            cp.compute_device_type = backend
        except TypeError:
            tentativa.append("%s: este build nao tem" % backend)
            continue
        cp.get_devices_for_type(backend)
        gpus = [d for d in cp.devices if d.type == backend]
        if not gpus:
            tentativa.append("%s: nenhuma GPU (driver?)" % backend)
            continue
        for d in cp.devices:
            d.use = (d.type == backend)
        return backend, [d.name for d in gpus], tentativa
    tentativa.append("CPU: %d nucleo(s)" % (os.cpu_count() or 0))
    if not permitir_cpu:
        falhar("nenhuma GPU encontrada (%s) e --cpu nao foi passado. "
               "A previa do projeto EXIGE GPU (D62)." % "; ".join(tentativa))
    cp.compute_device_type = "NONE"
    return "NONE", ["CPU (%d nucleos)" % (os.cpu_count() or 0)], tentativa


# ---------- cenario de estudio (identico para todo asset) ----------

def limpar():
    bpy.ops.wm.read_homefile(use_empty=True)


def medida_do_asset():
    """A caixa de tudo que tem malha: e ela que decide o enquadramento."""
    deps = bpy.context.evaluated_depsgraph_get()
    menor = [1e9, 1e9, 1e9]
    maior = [-1e9, -1e9, -1e9]
    malhas = 0
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        malhas += 1
        me = ob.evaluated_get(deps).to_mesh()
        for v in me.vertices:
            p = ob.matrix_world @ v.co
            for i in range(3):
                menor[i] = min(menor[i], p[i])
                maior[i] = max(maior[i], p[i])
        ob.evaluated_get(deps).to_mesh_clear()
    if malhas == 0:
        falhar("o arquivo aberto nao tem nenhuma malha para fotografar")
    return Vector(menor), Vector(maior), malhas


def montar_estudio(menor, maior):
    """3 luzes + fundo. Nao ha HDRI nem arquivo externo: a previa nao pode
    depender de nada que nao este script."""
    s = bpy.context.scene

    mundo = bpy.data.worlds.new("mundo_preview")
    if mundo.node_tree is None and hasattr(mundo, "use_nodes"):
        mundo.use_nodes = True
    fundo = mundo.node_tree.nodes["Background"]
    fundo.inputs[0].default_value = FUNDO
    fundo.inputs[1].default_value = 1.0
    s.world = mundo

    def luz(nome, tipo, energia, pos, tamanho=4.0):
        dados = bpy.data.lights.new(nome, type=tipo)
        dados.energy = energia
        if tipo == "AREA":
            dados.size = tamanho
        ob = bpy.data.objects.new(nome, dados)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = pos
        return ob

    # key (frontal alta), fill (lateral baixa e fraca), rim (atras, forte)
    key = luz("key", "AREA", 900.0, (2.6, -3.0, 4.2), 5.0)
    key.rotation_euler = (0.95, 0.0, 0.55)
    fill = luz("fill", "AREA", 220.0, (-3.4, -1.8, 1.4), 6.0)
    fill.rotation_euler = (1.25, 0.0, -1.15)
    rim = luz("rim", "AREA", 700.0, (-1.2, 3.6, 3.0), 4.0)
    rim.rotation_euler = (-1.05, 0.0, 3.6)


def enquadrar(menor, maior):
    """Camera 3/4 que enquadra a caixa INTEIRA com uma folga fixa. A mesma
    regra para todo asset, e por isso que duas previas se comparam."""
    centro = (menor + maior) * 0.5
    diagonal = (maior - menor).length
    if diagonal <= 0.0:
        diagonal = 1.0
    dados = bpy.data.cameras.new("cam_preview")
    dados.lens = 70.0
    cam = bpy.data.objects.new("cam_preview", dados)
    bpy.context.scene.collection.objects.link(cam)
    dist = diagonal * 1.9
    altura = diagonal * 0.72
    cam.location = Vector((centro.x + dist * 0.52, centro.y - dist * 0.80, centro.z + altura))
    cam.rotation_euler = (centro - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def configurar_render(samples, res):
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.device = "GPU"
    s.cycles.samples = samples
    s.cycles.use_denoising = True
    s.cycles.seed = SEMENTE
    s.cycles.use_animated_seed = False
    if hasattr(s.cycles, "use_adaptive_sampling"):
        s.cycles.use_adaptive_sampling = True
        s.cycles.adaptive_threshold = 0.01
    if hasattr(s.cycles, "max_bounces"):
        s.cycles.max_bounces = 8
        s.cycles.transmission_bounces = 4
    s.render.resolution_x = res
    s.render.resolution_y = res
    s.render.resolution_percentage = 100
    s.render.film_transparent = False
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGB"
    s.render.image_settings.color_depth = "8"
    s.render.image_settings.compression = 15
    s.view_settings.view_transform = "AgX"
    s.view_settings.look = "None"
    s.view_settings.exposure = 0.0
    s.view_settings.gamma = 1.0


def main():
    d = argumentos()
    if not d["out"]:
        falhar("falta --out <arquivo.png> (a prova vai para fora do repo)")

    origem = ""
    if d["asset"]:
        origem = os.path.join(DIR_FONTE, "%s.blend" % d["asset"])
        if not os.path.exists(origem):
            falhar("asset '%s' sem fonte em %s. Salve o .blend nessa pasta "
                   "(abra o Blender pelo abrir_blender.ps1 e salve la)." % (d["asset"], DIR_FONTE))
    elif d["blend"]:
        origem = os.path.abspath(d["blend"])
        if not os.path.exists(origem):
            falhar("arquivo .blend nao existe: %s" % origem)
    else:
        falhar("informe --asset <id> ou --blend <caminho>")

    saida = os.path.abspath(d["out"])
    pasta = os.path.dirname(saida)
    if pasta and not os.path.isdir(pasta):
        os.makedirs(pasta, exist_ok=True)

    backend, gpus, tentativas = configurar_gpu(d["cpu"])
    print("PREVIEW gpu: backend=%s dispositivos=%s" % (backend, ", ".join(gpus)))
    for t in tentativas:
        print("PREVIEW   (tentou %s)" % t)

    limpar()
    bpy.ops.wm.open_mainfile(filepath=origem)
    menor, maior, malhas = medida_do_asset()
    print("PREVIEW asset: %s | %d malha(s) | caixa %s .. %s" % (
        os.path.basename(origem), malhas,
        tuple(round(v, 4) for v in menor), tuple(round(v, 4) for v in maior)))

    montar_estudio(menor, maior)
    enquadrar(menor, maior)
    configurar_render(d["samples"], d["res"])
    bpy.context.scene.render.filepath = saida

    inicio = time.time()
    bpy.ops.render.render(write_still=True)
    decorrido = time.time() - inicio

    if not os.path.exists(saida):
        falhar("o render nao gerou arquivo em %s" % saida)
    with open(saida, "rb") as f:
        dados = f.read()
    print("PREVIEW ok: %s" % saida)
    print("PREVIEW   %d bytes | %dx%d | %d amostras | semente %d | %.1f s" % (
        len(dados), d["res"], d["res"], d["samples"], SEMENTE, decorrido))
    print("PREVIEW   sha256 %s" % hashlib.sha256(dados).hexdigest())
    if d["comparar"]:
        antes = os.path.abspath(d["comparar"])
        if not os.path.exists(antes):
            print("PREVIEW   (nao comparou: %s nao existe)" % antes)
        else:
            ab = comparar_pngs(antes, saida)
            if "erro" in ab:
                print("PREVIEW   (nao comparou: %s)" % ab["erro"])
            else:
                print("PREVIEW A/B vs %s" % os.path.basename(antes))
                print("PREVIEW   %d de %d pixels mudaram (%.4f%%) | delta max %.4f | delta medio %.6f" % (
                    ab["mudados"], ab["pixels"], ab["porcentagem"], ab["delta_max"], ab["delta_medio"]))
    print("PREVIEW FIM")


main()

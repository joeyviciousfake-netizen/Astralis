"""Reparo regional do Astralis (passo 2: inpaint da parte que faltou).

Fluxo: checa a parte na gerada -> acha o corpo -> mascara o alvo ->
inpaint com o crop da referencia (IPAdapter) + texto da parte, denoise
baixo (nao mexe no resto).

Uso:
    python tools/comfy/reparo.py <gerada> <ref> <ficha> <parte>
        [--denoise 0.35] [--saida <png>]
Ex.:
    python tools/comfy/reparo.py gen.png ref.jpg fichas/relogio.json relogio
"""
import json
import os
import sys
import tempfile
import time
import urllib.parse
import urllib.request

BASE = "http://127.0.0.1:8188"
INPAINT = "sdxl-1.0-inpainting-0.1"
IPADAPTER = "ip-adapter-plus_sdxl_vit-h.safetensors"
CLIP_VISION = "CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"

PROMPT_PARTE = {
    "relogio": "large blue circular clock-face disk with green hour and minute "
               "hands and small red center dot, mounted flat facing viewer",
}


def api(method, path, data=None):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Content-Type": "application/json"}, method=method)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def reparar(gen_path, ref_path, ficha_path, parte, denoise=0.35, saida=None,
            seed=11):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from limpar import upload
    from partes import caixas, recortar, mascara_caixa
    from PIL import Image
    ficha = json.load(open(ficha_path, encoding="utf-8"))
    crit = next(c for c in ficha["partes_criticas"] if c["nome"] == parte)
    # corpo na gerada -> alvo = parte central do corpo
    corpo = caixas(gen_path, "red round body")
    if not corpo:
        raise SystemExit("corpo nao achado na gerada")
    caixas_corpo = list(corpo.values())[0]
    def area(b):
        return (b[2] - b[0]) * (b[3] - b[1])
    # a 1a caixa costuma ser a imagem inteira: pega a menor util (>=2%)
    validas = [b for b in caixas_corpo if area(b) >= 20000] or caixas_corpo
    b = min(validas, key=area)
    cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
    wbox, hbox = (b[2] - b[0]) * 0.55, (b[3] - b[1]) * 0.45
    alvo = [cx - wbox / 2, cy - hbox / 2 + 30, cx + wbox / 2, cy + hbox / 2 + 30]
    # crop da parte na referencia
    refbox = caixas(ref_path, crit["frase"])
    if not refbox:
        raise SystemExit("parte nao achada na referencia")
    crop = recortar(ref_path, list(refbox.values())[0][0], margem=0.25,
                    saida=tempfile.mktemp(suffix="_crop.png"))
    im = Image.open(gen_path).convert("RGB")
    tmpm = tempfile.mktemp(suffix="_mask.png")
    mascara_caixa(im.size, alvo, saida=tmpm)
    up_img, up_mask, up_crop = upload(gen_path), upload(tmpm), upload(crop)
    os.remove(tmpm)
    prompt = PROMPT_PARTE.get(parte, crit["frase"])
    wf = {
        "1": {"class_type": "DiffusersLoader", "inputs": {"model_path": INPAINT}},
        "2": {"class_type": "LoadImage", "inputs": {"image": up_img["name"]}},
        "3": {"class_type": "LoadImage", "inputs": {"image": up_mask["name"]}},
        "3b": {"class_type": "ImageToMask",
               "inputs": {"image": ["3", 0], "channel": "red"}},
        "5": {"class_type": "CLIPTextEncode",
              "inputs": {"text": prompt, "clip": ["1", 1]}},
        "6": {"class_type": "CLIPTextEncode",
              "inputs": {"text": "text, watermark, blurry, deformed",
                         "clip": ["1", 1]}},
        "20": {"class_type": "IPAdapterModelLoader",
               "inputs": {"ipadapter_file": IPADAPTER}},
        "21": {"class_type": "CLIPVisionLoader",
               "inputs": {"clip_name": CLIP_VISION}},
        "22": {"class_type": "LoadImage", "inputs": {"image": up_crop["name"]}},
        "23": {"class_type": "IPAdapterAdvanced",
               "inputs": {"model": ["1", 0], "ipadapter": ["20", 0],
                          "image": ["22", 0], "clip_vision": ["21", 0],
                          "weight": 0.7, "weight_type": "strong middle",
                          "combine_embeds": "concat", "start_at": 0.0,
                          "end_at": 1.0, "embeds_scaling": "V only"}},
        "7": {"class_type": "InpaintModelConditioning",
              "inputs": {"positive": ["5", 0], "negative": ["6", 0],
                         "pixels": ["2", 0], "vae": ["1", 2],
                         "mask": ["3b", 0], "noise_mask": True}},
        "8": {"class_type": "KSampler",
              "inputs": {"seed": seed, "steps": 24, "cfg": 5.0,
                         "sampler_name": "euler_ancestral", "scheduler": "karras",
                         "denoise": denoise, "model": ["23", 0],
                         "positive": ["7", 0], "negative": ["7", 1],
                         "latent_image": ["7", 2]}},
        "9": {"class_type": "VAEDecode",
              "inputs": {"samples": ["8", 0], "vae": ["1", 2]}},
        "10": {"class_type": "SaveImage",
               "inputs": {"images": ["9", 0], "filename_prefix": "astralis_reparo"}},
    }
    pid = api("POST", "/prompt", {"prompt": wf})["prompt_id"]
    print("trabalho:", pid, flush=True)
    for _ in range(60):
        time.sleep(5)
        h = api("GET", f"/history/{pid}")
        if pid in h and h[pid].get("status", {}).get("completed"):
            for im in h[pid]["outputs"]["10"]["images"]:
                print("PRONTO: output/%s" % im["filename"], flush=True)
                q = urllib.parse.urlencode(
                    {"filename": im["filename"], "subfolder": im["subfolder"],
                     "type": im["type"]})
                raw = urllib.request.urlopen(f"{BASE}/view?{q}",
                                             timeout=120).read()
                dst = saida or os.path.splitext(gen_path)[0] + "_reparo.png"
                open(dst, "wb").write(raw)
                print("REPARO:", dst, flush=True)
                receita = {"trabalho": pid, "gerada": gen_path, "parte": parte,
                           "alvo": [round(x) for x in alvo], "denoise": denoise,
                           "seed": seed,
                           "fluxo_tela": "tools/comfy/workflows/reparo_tela.json"}
                try:
                    outdir = os.path.join(os.path.expanduser("~"), "AppData",
                                          "Local", "Comfy-Desktop", "ComfyUI-Shared",
                                          "output")
                    base = os.path.splitext(im["filename"])[0] + ".job.json"
                    json.dump(receita, open(os.path.join(outdir, base), "w",
                                            encoding="utf-8"),
                              ensure_ascii=False, indent=1)
                except OSError:
                    pass
            os.remove(crop)
            return
    raise TimeoutError("reparo demorou demais (5 min)")


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) < 4:
        print("uso: reparo.py <gerada> <ref> <ficha> <parte> [--denoise N] [--saida P]")
        sys.exit(1)
    reparar(a[0], a[1], a[2], a[3],
            denoise=float(a[a.index("--denoise") + 1]) if "--denoise" in a else 0.35,
            saida=a[a.index("--saida") + 1] if "--saida" in a else None)

"""Limpador automatico do Astralis (via ComfyUI inpainting).

Apaga assinatura/marca fantasma que escapa na geracao (sempre na borda
de baixo) reconstruindo o fundo com o modelo de inpainting.

Uso:
    python tools/comfy/limpar.py <imagem> [--base 10] [--saida <png>]

Requer o ComfyUI Desktop aberto.
"""
import io
import json
import mimetypes
import os
import sys
import time
import urllib.parse
import urllib.request

BASE = "http://127.0.0.1:8188"
INPAINT = "sdxl-1.0-inpainting-0.1"


def api(method, path, data=None):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Content-Type": "application/json"}, method=method)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def upload(caminho):
    limite = "----astralis1234"
    nome = os.path.basename(caminho)
    with open(caminho, "rb") as f:
        dados = f.read()
    corpo = (
        f"--{limite}\r\nContent-Disposition: form-data; name=\"image\"; "
        f"filename=\"{nome}\"\r\nContent-Type: "
        f"{mimetypes.guess_type(nome)[0] or 'application/octet-stream'}\r\n\r\n"
    ).encode() + dados + (
        f"\r\n--{limite}\r\nContent-Disposition: form-data; "
        f"name=\"overwrite\"\r\n\r\ntrue\r\n--{limite}--\r\n"
    ).encode()
    req = urllib.request.Request(
        BASE + "/upload/image", data=corpo,
        headers={"Content-Type": f"multipart/form-data; boundary={limite}"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def máscara_base(img_path, pct, tmp):
    from PIL import Image
    im = Image.open(img_path).convert("RGB")
    w, h = im.size
    import PIL.ImageDraw as D
    mask = Image.new("L", (w, h), 0)
    d = D.Draw(mask)
    d.rectangle([0, int(h * (1 - pct / 100)), w, h], fill=255)
    mask.save(tmp)
    return tmp


def limpar(img_path, pct_base=10, saida=None, denoise=0.9,
           prompt_fundo="plain dark smoky background, empty, seamless, no text no watermark no signature"):
    up_img = upload(img_path)
    mask_tmp = img_path + ".mask.png"
    máscara_base(img_path, pct_base, mask_tmp)
    up_mask = upload(mask_tmp)
    os.remove(mask_tmp)
    neg = "text, watermark, signature, deformed, blurry"
    wf = {
        "1": {"class_type": "DiffusersLoader",
              "inputs": {"model_path": INPAINT}},
        "2": {"class_type": "LoadImage",
              "inputs": {"image": up_img["name"]}},
        "3": {"class_type": "LoadImage",
              "inputs": {"image": up_mask["name"]}},
        "3b": {"class_type": "ImageToMask",
               "inputs": {"image": ["3", 0], "channel": "red"}},
        "5": {"class_type": "CLIPTextEncode",
              "inputs": {"text": prompt_fundo, "clip": ["1", 1]}},
        "6": {"class_type": "CLIPTextEncode",
              "inputs": {"text": neg, "clip": ["1", 1]}},
        "7": {"class_type": "InpaintModelConditioning",
              "inputs": {"positive": ["5", 0], "negative": ["6", 0],
                         "pixels": ["2", 0], "vae": ["1", 2],
                         "mask": ["3b", 0], "noise_mask": True}},
        "8": {"class_type": "KSampler",
              "inputs": {"seed": 7, "steps": 24, "cfg": 5.0,
                         "sampler_name": "euler_ancestral", "scheduler": "karras",
                         "denoise": denoise, "model": ["1", 0],
                         "positive": ["7", 0], "negative": ["7", 1],
                         "latent_image": ["7", 2]}},
        "9": {"class_type": "VAEDecode",
              "inputs": {"samples": ["8", 0], "vae": ["1", 2]}},
        "10": {"class_type": "SaveImage",
               "inputs": {"images": ["9", 0], "filename_prefix": "astralis_limpo"}},
    }
    pid = api("POST", "/prompt", {"prompt": wf})["prompt_id"]
    print("trabalho:", pid, flush=True)
    for _ in range(60):
        time.sleep(5)
        h = api("GET", f"/history/{pid}")
        if pid in h and h[pid].get("status", {}).get("completed"):
            ims = h[pid]["outputs"]["10"]["images"]
            for im in ims:
                q = urllib.parse.urlencode(
                    {"filename": im["filename"], "subfolder": im["subfolder"],
                     "type": im["type"]})
                raw = urllib.request.urlopen(f"{BASE}/view?{q}", timeout=60).read()
                dst = saida or os.path.splitext(img_path)[0] + "_limpo.png"
                open(dst, "wb").write(raw)
                print("LIMPO:", dst, flush=True)
                receita = {"trabalho": pid, "imagem": img_path,
                           "faixa_base_pct": pct_base, "denoise": denoise,
                           "fluxo_tela": "tools/comfy/workflows/limpar_tela.json"}
                try:
                    outdir = os.path.join(os.path.expanduser("~"),
                                          "AppData", "Local", "Comfy-Desktop",
                                          "ComfyUI-Shared", "output")
                    base = os.path.splitext(im["filename"])[0] + ".job.json"
                    json.dump(receita, open(os.path.join(outdir, base), "w", encoding="utf-8"),
                              ensure_ascii=False, indent=1)
                    print("receita:", base, flush=True)
                except OSError:
                    pass
            return
    raise TimeoutError("limpeza demorou demais")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("uso: limpar.py <imagem> [--base 10] [--saida <png>]")
        sys.exit(1)
    args = sys.argv[1:]
    pct, out, denoise = 10, None, 0.9
    if "--base" in args:
        pct = float(args[args.index("--base") + 1])
    if "--saida" in args:
        out = args[args.index("--saida") + 1]
    if "--denoise" in args:
        denoise = float(args[args.index("--denoise") + 1])
    limpar(args[0], pct, out, denoise)

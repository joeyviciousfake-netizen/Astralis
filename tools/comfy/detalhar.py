"""Refinador do Astralis: detecta maos/rostos e refaz cada regiao em alta.

RODAR COM O PYTHON DO COMFY (tem ultralytics):
"C:/Users/Max/AppData/Local/Comfy-Desktop/ComfyUI-Installs/ComfyUI/ComfyUI/.venv/Scripts/python.exe" tools/comfy/detalhar.py <imagem> [--saida <png>]

1. YOLO (.pt) acha maos e rostos na imagem.
2. Cada achado e recortado com margem e refeito via inpainting no ComfyUI.
3. Cola de volta com pena — sem costura.
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
PASTA_MODELOS = ("C:/Users/Max/AppData/Local/Comfy-Desktop/"
                 "ComfyUI-Shared/models/ultralytics/bbox")
PROMPTS = {
    "hand_yolov8s.pt": "detailed hand, five natural fingers, correct anatomy",
    "face_yolov8m.pt": "detailed beautiful face, symmetrical eyes, clean skin",
}

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def api(method, path, data=None):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Content-Type": "application/json"}, method=method)
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def upload_img(caminho, nome=None):
    limite = "----astralis9"
    nome = nome or os.path.basename(caminho)
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
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.load(r)


def baixar(nome, sub="", tipo="output"):
    q = urllib.parse.urlencode({"filename": nome, "subfolder": sub, "type": tipo})
    return urllib.request.urlopen(f"{BASE}/view?{q}", timeout=120).read()


def inpaint_arquivo(up_img, up_mask, prompt, seed=11):
    neg = "deformed, blurry, extra fingers, text, watermark"
    wf = {
        "1": {"class_type": "DiffusersLoader",
              "inputs": {"model_path": INPAINT}},
        "2": {"class_type": "LoadImage", "inputs": {"image": up_img["name"]}},
        "3": {"class_type": "LoadImage", "inputs": {"image": up_mask["name"]}},
        "3b": {"class_type": "ImageToMask",
               "inputs": {"image": ["3", 0], "channel": "red"}},
        "5": {"class_type": "CLIPTextEncode",
              "inputs": {"text": prompt, "clip": ["1", 1]}},
        "6": {"class_type": "CLIPTextEncode",
              "inputs": {"text": neg, "clip": ["1", 1]}},
        "7": {"class_type": "InpaintModelConditioning",
              "inputs": {"positive": ["5", 0], "negative": ["6", 0],
                         "pixels": ["2", 0], "vae": ["1", 2],
                         "mask": ["3b", 0], "noise_mask": True}},
        "8": {"class_type": "KSampler",
              "inputs": {"seed": seed, "steps": 24, "cfg": 5.5,
                         "sampler_name": "euler_ancestral",
                         "scheduler": "karras", "denoise": 0.55,
                         "model": ["1", 0], "positive": ["7", 0],
                         "negative": ["7", 1], "latent_image": ["7", 2]}},
        "9": {"class_type": "VAEDecode",
              "inputs": {"samples": ["8", 0], "vae": ["1", 2]}},
        "10": {"class_type": "SaveImage",
               "inputs": {"images": ["9", 0], "filename_prefix": "astralis_det"}},
    }
    pid = api("POST", "/prompt", {"prompt": wf})["prompt_id"]
    for _ in range(100):
        time.sleep(5)
        h = api("GET", f"/history/{pid}")
        if pid in h and h[pid].get("status", {}).get("completed"):
            return h[pid]["outputs"]["10"]["images"][0]
    raise TimeoutError("inpaint demorou")


def detalhar(img_path, saida=None):
    from PIL import Image, ImageFilter
    from ultralytics import YOLO

    base = Image.open(img_path).convert("RGB")
    W, H = base.size
    tmp = os.path.join(os.path.dirname(os.path.abspath(img_path)), "_det_tmp")
    os.makedirs(tmp, exist_ok=True)

    for modelo, prompt in PROMPTS.items():
        yolo = YOLO(os.path.join(PASTA_MODELOS, modelo))
        achados = 0
        for r in yolo.predict(img_path, conf=0.3, verbose=False):
            for b in r.boxes:
                x1, y1, x2, y2 = (int(v) for v in b.xyxy[0].tolist())
                cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
                lado = max(x2 - x1, y2 - y1) * 1.7
                lado = max(lado, 384)
                qx0 = int(max(cx - lado / 2, 0))
                qy0 = int(max(cy - lado / 2, 0))
                qx1 = int(min(cx + lado / 2, W))
                qy1 = int(min(cy + lado / 2, H))
                rec = base.crop((qx0, qy0, qx1, qy1))
                escala = 768 / max(rec.size)
                rec_r = rec.resize((int(rec.width * escala), int(rec.height * escala)))
                pcrop = os.path.join(tmp, "crop.png")
                pmask = os.path.join(tmp, "mask.png")
                rec_r.save(pcrop)
                mw, mh = rec_r.size
                m = Image.new("L", (mw, mh), 0)
                from PIL import ImageDraw
                d = ImageDraw.Draw(m)
                d.ellipse([mw * 0.12, mh * 0.12, mw * 0.88, mh * 0.88], fill=255)
                m.save(pmask)
                up_c = upload_img(pcrop, "det_crop.png")
                up_m = upload_img(pmask, "det_mask.png")
                res = inpaint_arquivo(up_c, up_m, prompt)
                novo = Image.open(io.BytesIO(baixar(res["filename"]))).convert("RGB")
                novo = novo.resize(rec.size)
                alfa = Image.new("L", rec.size, 0)
                da = ImageDraw.Draw(alfa)
                da.ellipse([rec.width * 0.18, rec.height * 0.18,
                            rec.width * 0.82, rec.height * 0.82], fill=255)
                alfa = alfa.filter(ImageFilter.GaussianBlur(14))
                base.paste(novo, (qx0, qy0), alfa)
                achados += 1
        print(f"{modelo}: {achados} regiao(oes) refeita(s)", flush=True)

    dst = saida or os.path.splitext(img_path)[0] + "_det.png"
    base.save(dst)
    import shutil
    shutil.rmtree(tmp, ignore_errors=True)
    print("PRONTO:", dst, flush=True)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("uso: detalhar.py <imagem> [--saida <png>]")
        sys.exit(1)
    out = None
    if "--saida" in sys.argv:
        out = sys.argv[sys.argv.index("--saida") + 1]
    detalhar(sys.argv[1], out)

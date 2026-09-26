"""Partes do personagem (grounding Florence, sem node novo).

Acha partes por frase ("blue clock face" -> caixas 0..1000), recorta,
gera mascara e CHECA presenca/posicao em imagem gerada. E a base do
IPAdapter regional + do inpaint de reparo + da metrica por partes.

Uso:
    python tools/comfy/partes.py caixas <img> "<frase de ancoragem>"
    python tools/comfy/partes.py checar <img_gerada> <ficha.json>
"""
import json
import os
import re
import sys
import time
import urllib.request

BASE = "http://127.0.0.1:8188"
MODELO = "microsoft/Florence-2-base"


def api(method, path, data=None):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Content-Type": "application/json"}, method=method)
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def caixas(img_path, frase):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from limpar import upload
    up = upload(img_path)
    wf = {
        "1": {"class_type": "DownloadAndLoadFlorence2Model",
              "inputs": {"model": MODELO, "precision": "fp16"}},
        "2": {"class_type": "LoadImage", "inputs": {"image": up["name"]}},
        "3": {"class_type": "Florence2Run",
              "inputs": {"image": ["2", 0], "florence2_model": ["1", 0],
                         "text_input": frase, "task": "caption_to_phrase_grounding",
                         "fill_mask": True}},
        "4": {"class_type": "PreviewAny", "inputs": {"source": ["3", 2]}},
    }
    pid = api("POST", "/prompt", {"prompt": wf})["prompt_id"]
    for _ in range(60):
        time.sleep(5)
        h = api("GET", f"/history/{pid}")
        if pid in h and h[pid].get("status", {}).get("completed"):
            txt = h[pid]["outputs"]["4"]["text"][0]
            ach = {}
            for parte in re.split(r"(?<=>)(?=[a-z])", txt):
                m = re.match(r"(.+?)((?:<loc_\d+>)+)", parte)
                if not m:
                    continue
                nums = [int(x) for x in re.findall(r"<loc_(\d+)>", m.group(2))]
                grupo = [nums[i:i + 4] for i in range(0, len(nums), 4)]
                ach[m.group(1).strip()] = grupo
            return ach
    raise TimeoutError("grounding demorou demais (5 min)")


def centro(box):
    x0, y0, x1, y1 = box
    return ((x0 + x1) / 2, (y0 + y1) / 2)


def checar(img_path, ficha_path):
    """Regras em ficha['partes_criticas']: [{nome, frase, regiao:[x0,y0,x1,y1]?}].
    Volta {nome: {ok, caixas, detalhe}}."""
    ficha = json.load(open(ficha_path, encoding="utf-8"))
    crit = ficha.get("partes_criticas", [])
    frases = ", ".join(c["frase"] for c in crit)
    ach = caixas(img_path, ficha.get("frase_ancora", "a cartoon character") +
                 (", " + frases if frases else ""))
    rel = {}
    for c in crit:
        boxes = ach.get(c["frase"], [])
        ok, det = True, f"{len(boxes)} caixa(s)"
        if not boxes:
            ok, det = False, "ausente"
        elif "regiao" in c:
            x0, y0, x1, y1 = c["regiao"]
            cx, cy = centro(boxes[0])
            if not (x0 <= cx <= x1 and y0 <= cy <= y1):
                ok, det = False, f"fora do lugar ({cx:.0f},{cy:.0f})"
            else:
                det = f"no lugar ({cx:.0f},{cy:.0f})"
        rel[c["nome"]] = {"ok": ok, "caixas": boxes, "detalhe": det}
    return rel


def recortar(img_path, box, margem=0.1, saida=None):
    from PIL import Image
    im = Image.open(img_path).convert("RGB")
    w, h = im.size
    x0, y0, x1, y1 = [b / 1000 for b in box]
    dx, dy = (x1 - x0) * margem, (y1 - y0) * margem
    crop = im.crop((int(max(0, x0 - dx) * w), int(max(0, y0 - dy) * h),
                    int(min(1, x1 + dx) * w), int(min(1, y1 + dy) * h)))
    saida = saida or os.path.splitext(img_path)[0] + "_crop.png"
    crop.save(saida)
    return saida


def mascara_caixa(tamanho, box, pena=30, saida=None):
    from PIL import Image, ImageDraw, ImageFilter
    w, h = tamanho
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    x0, y0, x1, y1 = box[0] / 1000 * w, box[1] / 1000 * h, \
        box[2] / 1000 * w, box[3] / 1000 * h
    d.rounded_rectangle([x0, y0, x1, y1], radius=pena, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(pena // 2))
    m.save(saida)
    return saida


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) < 2 or a[0] not in ("caixas", "checar"):
        print("uso: partes.py caixas <img> <frase> | checar <img> <ficha>")
        sys.exit(1)
    if a[0] == "caixas":
        print(json.dumps(caixas(a[1], a[2]), ensure_ascii=False, indent=1))
    else:
        rel = checar(a[1], a[2])
        for nome, r in rel.items():
            print(("OK  " if r["ok"] else "FALTA"), nome, "-", r["detalhe"])

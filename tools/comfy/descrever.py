"""Descritor do Astralis (via Florence-2 no ComfyUI).

Olha a imagem e escreve sozinho a descricao detalhada — vira prompt
p/ gerar parecido sem copiar o desenho.

Uso:
    python tools/comfy/descrever.py <imagem> [--saida <txt>]

Requer o ComfyUI Desktop aberto (o modelo baixa sozinho no 1o uso).
"""
import json
import mimetypes
import os
import sys
import time
import urllib.request

BASE = "http://127.0.0.1:8188"


def api(method, path, data=None):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Content-Type": "application/json"}, method=method)
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def upload(caminho):
    limite = "----astralis7"
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
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.load(r)


def descrever(img_path, saida=None):
    up = upload(img_path)
    wf = {
        "1": {"class_type": "DownloadAndLoadFlorence2Model",
              "inputs": {"model": "microsoft/Florence-2-base",
                         "precision": "fp16"}},
        "2": {"class_type": "LoadImage", "inputs": {"image": up["name"]}},
        "3": {"class_type": "Florence2Run",
              "inputs": {"image": ["2", 0],
                         "florence2_model": ["1", 0],
                         "text_input": "",
                         "task": "more_detailed_caption",
                         "fill_mask": True}},
        "4": {"class_type": "PreviewAny",
              "inputs": {"source": ["3", 2]}},
    }
    pid = api("POST", "/prompt", {"prompt": wf})["prompt_id"]
    print("trabalho:", pid, flush=True)
    for _ in range(100):
        time.sleep(5)
        h = api("GET", f"/history/{pid}")
        if pid in h and h[pid].get("status", {}).get("completed"):
            outs = h[pid]["outputs"]
            for nid, o in outs.items():
                val = o.get("caption", o.get("text"))
                if val:
                    txt = val[0] if isinstance(val, list) else str(val)
                    print("DESCRICAO:", txt, flush=True)
                    if saida:
                        open(saida, "w", encoding="utf-8").write(txt)
                        print("salvo:", saida, flush=True)
                    return txt
            print("saidas:", list(outs.keys()), flush=True)
            return
    raise TimeoutError("descricao demorou")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("uso: descrever.py <imagem> [--saida <txt>]")
        sys.exit(1)
    out = None
    if "--saida" in sys.argv:
        out = sys.argv[sys.argv.index("--saida") + 1]
    descrever(sys.argv[1], out)

"""Gerador fiel do Astralis (workflow v2: identidade + pose).

Receita profissional p/ "mesmo personagem, pose nova", igual p/ os 700:
  IDENTIDADE (o que nao muda): referencia via IPAdapter + bloco de
    aparencia da ficha (ficha/*.json, 1 por personagem).
  POSE (o que muda): esqueleto via ControlNet Union + acao em texto.
  Texto nunca tenta redescrever a identidade sozinho.

Uso:
    python tools/comfy/gerar_fiel.py --ref <img> --ficha <ficha.json>
        --pose voar_lancar --acao "casting a green time vortex spell"
        [--peso-id 0.6] [--tipo-id "strong middle"] [--forca-pose 0.7]
        [--seed N] [--sem-estilo]

Tudo auditavel no .job.json junto da imagem (prompt, ficha, ref, pesos,
pose, seed, modelo, workflow de tela).
"""
import hashlib
import json
import os
import random
import sys
import tempfile
import time
import urllib.parse
import urllib.request

BASE = "http://127.0.0.1:8188"
CKPT = "Illustrious-XL-v2.0.safetensors"
LORA_ESTILO = "yugioh_style_illustrious.safetensors"
FORCA_ESTILO = 0.7
GATILHO_ESTILO = "yugioh_style"
IPADAPTER = "ip-adapter-plus_sdxl_vit-h.safetensors"
CLIP_VISION = "CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"
CONTROLNET = "controlnet-union-sdxl-1.0.safetensors"
PESO_ID = 0.6
TIPO_ID = "strong middle"
FORCA_POSE = 0.7
NEGATIVO = ("bad quality, worst quality, sketch, blurry, censored, "
            "text, letters, words, caption, watermark, signature, username, "
            "logo, copyright, card frame, border, text box, ui, interface")


def api(method, path, data=None):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Content-Type": "application/json"}, method=method)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def gerar(ref, ficha_path, pose_nome, acao, width=1024, height=1024,
          steps=28, cfg=6.0, seed=None, estilo=True, ckpt=CKPT,
          peso_id=PESO_ID, tipo_id=TIPO_ID, forca_pose=FORCA_POSE,
          negative=NEGATIVO):
    seed = seed if seed is not None else random.randint(0, 2**31 - 1)
    ficha = json.load(open(ficha_path, encoding="utf-8"))
    aparencia = ficha["prompt_aparencia"]
    proibido = ", ".join(ficha.get("nao_fazer", []))
    if proibido:
        negative = f"{negative}, {proibido}"
    prompt_pos = f"{GATILHO_ESTILO + ', ' if estilo else ''}{aparencia}, {acao}, " \
        "trading card game illustration, detailed anime fantasy art, masterpiece"
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from limpar import upload
    from pose import desenhar
    up_ref = upload(ref)
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tf:
        desenhar(pose_nome, max(width, height)).save(tf.name)
        up_pose = upload(tf.name)
    os.remove(tf.name)
    wf = {
        "1": {"class_type": "CheckpointLoaderSimple",
              "inputs": {"ckpt_name": ckpt}},
        "2": {"class_type": "CLIPSetLastLayer",
              "inputs": {"stop_at_clip_layer": -2, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode",
              "inputs": {"text": prompt_pos, "clip": ["2", 0]}},
        "4": {"class_type": "CLIPTextEncode",
              "inputs": {"text": negative, "clip": ["2", 0]}},
        "5": {"class_type": "EmptyLatentImage",
              "inputs": {"width": width, "height": height, "batch_size": 1}},
        "9": {"class_type": "LoraLoader",
              "inputs": {"lora_name": LORA_ESTILO,
                         "strength_model": FORCA_ESTILO if estilo else 0.0,
                         "strength_clip": FORCA_ESTILO if estilo else 0.0,
                         "model": ["1", 0], "clip": ["2", 0]}},
        "20": {"class_type": "IPAdapterModelLoader",
               "inputs": {"ipadapter_file": IPADAPTER}},
        "21": {"class_type": "CLIPVisionLoader",
               "inputs": {"clip_name": CLIP_VISION}},
        "22": {"class_type": "LoadImage",
               "inputs": {"image": up_ref["name"]}},
        "23": {"class_type": "IPAdapterAdvanced",
               "inputs": {"model": ["9", 0], "ipadapter": ["20", 0],
                          "image": ["22", 0], "clip_vision": ["21", 0],
                          "weight": peso_id, "weight_type": tipo_id,
                          "combine_embeds": "concat", "start_at": 0.0,
                          "end_at": 1.0, "embeds_scaling": "V only"}},
        "30": {"class_type": "ControlNetLoader",
               "inputs": {"control_net_name": CONTROLNET}},
        "31": {"class_type": "LoadImage",
               "inputs": {"image": up_pose["name"]}},
        "32": {"class_type": "ControlNetApplyAdvanced",
               "inputs": {"positive": ["3", 0], "negative": ["4", 0],
                          "control_net": ["30", 0], "image": ["31", 0],
                          "strength": forca_pose, "start_percent": 0.0,
                          "end_percent": 1.0}},
        "6": {"class_type": "KSampler",
              "inputs": {"seed": seed, "steps": steps, "cfg": cfg,
                         "sampler_name": "euler_ancestral", "scheduler": "karras",
                         "denoise": 1.0, "model": ["23", 0],
                         "positive": ["32", 0], "negative": ["32", 1],
                         "latent_image": ["5", 0]}},
        "7": {"class_type": "VAEDecode",
              "inputs": {"samples": ["6", 0], "vae": ["1", 2]}},
        "8": {"class_type": "SaveImage",
              "inputs": {"images": ["7", 0], "filename_prefix": "astralis_fiel"}},
    }
    wf["3"]["inputs"]["clip"] = ["9", 1]
    wf["4"]["inputs"]["clip"] = ["9", 1]
    pid = api("POST", "/prompt", {"prompt": wf})["prompt_id"]
    print("trabalho:", pid, "| seed:", seed, flush=True)
    for _ in range(120):
        time.sleep(5)
        h = api("GET", f"/history/{pid}")
        if pid in h and h[pid].get("status", {}).get("completed"):
            for im in h[pid]["outputs"]["8"]["images"]:
                print("PRONTO: output/%s" % im["filename"], flush=True)
                receita = {"trabalho": pid, "seed": seed, "prompt": prompt_pos,
                           "ficha": os.path.basename(ficha_path),
                           "ficha_sha256": hashlib.sha256(
                               open(ficha_path, "rb").read()).hexdigest()[:12],
                           "referencia": ref, "peso_id": peso_id,
                           "tipo_id": tipo_id, "pose": pose_nome,
                           "acao": acao, "forca_pose": forca_pose,
                           "base": ckpt, "lora": LORA_ESTILO if estilo else None,
                           "controlnet": CONTROLNET,
                           "fluxo_tela": "tools/comfy/workflows/gerar_fiel_tela.json"}
                try:
                    outdir = os.path.join(os.path.expanduser("~"), "AppData",
                                          "Local", "Comfy-Desktop", "ComfyUI-Shared",
                                          "output")
                    base = os.path.splitext(im["filename"])[0] + ".job.json"
                    json.dump(receita, open(os.path.join(outdir, base), "w",
                                            encoding="utf-8"),
                              ensure_ascii=False, indent=1)
                    print("receita:", base, flush=True)
                except OSError:
                    pass
            return h[pid]["outputs"]["8"]["images"]
    raise TimeoutError("geracao demorou demais (10 min)")


if __name__ == "__main__":
    a = sys.argv[1:]
    def opt(nome, padrao=None):
        return a[a.index(nome) + 1] if nome in a else padrao
    ref, ficha = opt("--ref"), opt("--ficha")
    if not ref or not ficha:
        print("uso: gerar_fiel.py --ref <img> --ficha <json> --pose <nome> "
              "--acao <texto> [opcoes]")
        sys.exit(1)
    gerar(ref, ficha, opt("--pose", "voar_lancar"), opt("--acao", "heroic pose"),
          estilo="--sem-estilo" not in a,
          peso_id=float(opt("--peso-id", PESO_ID)),
          tipo_id=opt("--tipo-id", TIPO_ID),
          forca_pose=float(opt("--forca-pose", FORCA_POSE)),
          seed=int(opt("--seed")) if opt("--seed") else None)
